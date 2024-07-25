variable "image" {
  type    = string
  default = "${env("IMAGE")}"
}

variable "boxrelease" {
  type    = string
  default = "${env("BOXRELEASE")}"
}

variable "description" {
  type    = string
  default = "${env("BOX_DESC")}"
}

variable "headless" {
  type    = bool
  default = true
}

variable "iso_checksum" {
  type    = string
  default = "${env("ISO_CHECKSUM")}"
}

variable "iso_name" {
  type    = string
  default = "${env("ISO_NAME")}"
}

variable "iso_server" {
  type    = string
  default = "${env("ISO_SERVER")}"
}

variable "vbox_version" {
  type    = string
  default = "${env("VBOX_VERSION")}"
}

variable "builder" {
  type    = string
  default = "${env("PACKER_BUILDER")}"
}

variable "builder_short" {
  type    = string
  default = "${env("PACKER_BUILDER_SHORT")}"
}

source "qemu" "libvirt" {
  accelerator        = "kvm"
  boot_command       = ["<tab> inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/el-9/ks.cfg<enter><wait>"]
  boot_wait          = "20s"
  disk_compression   = true
  disk_interface     = "virtio"
  disk_size          = "81920M"
  format             = "qcow2"
  headless           = "${var.headless}"
  http_directory     = "http"
  iso_checksum       = "sha1:${var.iso_checksum}"
  iso_url            = "${var.iso_server}${var.iso_name}"
  memory             = 2048
  net_device         = "virtio-net"
  output_directory   = "../../workspace/packer-el9-x86_64-qemu"
  qemu_binary        = "qemu-kvm"
  qemuargs           = [["-cpu", "host"], ["-smp", "2"]]
  shutdown_command   = "/sbin/halt -h -p"
  shutdown_timeout   = "2m30s"
  ssh_password       = "eurolinux"
  ssh_port           = 22
  ssh_timeout        = "2h"
  ssh_username       = "root"
  vm_name            = "el9-x86_64-${var.image}.${var.builder_short}.qcow2"
}

source "virtualbox-iso" "virtualbox" {
  boot_command            = ["<tab> inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/el-9/ks.cfg<enter><wait>"]
  boot_wait               = "20s"
  cpus                    = 4
  disk_size               = 81920
  export_opts = [
    "--manifest",
    "--vsys", "0",
    "--description", "${var.description}",
    "--version", "${var.boxrelease}"
  ]
  format                  = "ova"
  guest_additions_path    = "VBoxGuestAdditions_{{ .Version }}.iso"
  guest_os_type           = "RedHat9_64"
  hard_drive_interface    = "sata"
  headless                = "${var.headless}"
  http_directory          = "http"
  iso_checksum            = "sha1:${var.iso_checksum}"
  iso_interface           = "sata"
  iso_url                 = "${var.iso_server}${var.iso_name}"
  memory                  = 4096
  output_directory        = "../../workspace/packer-el9-x86_64-virtualbox"
  shutdown_command        = "/sbin/halt -h -p"
  shutdown_timeout        = "2m30s"
  ssh_password            = "eurolinux"
  ssh_port                = 22
  ssh_timeout             = "2h"
  ssh_username            = "root"
  vboxmanage              = [["modifyvm", "{{ .Name }}", "--nat-localhostreachable1", "on"]]
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--memory", "2048"],
    ["modifyvm", "{{.Name}}", "--cpus", "2"]
  ]
  virtualbox_version_file = ".vbox_version"
  vm_name                 = "el9-x86_64-${var.image}.${var.builder_short}"
}

source "vmware-iso" "vmware_workstation" {
  boot_command        = ["<tab> inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/el-9/ks.cfg<enter><wait>"]
  boot_wait           = "20s"
  cpus                = 4
  memory              = 2048
  format              = "ova"
  disk_size           = 81920
  disk_adapter_type   = "scsi"
  disk_type_id        = "0"
  guest_os_type       = "linux"
  headless            = "${var.headless}"
  http_directory      = "http"
  iso_checksum        = "sha1:${var.iso_checksum}"
  iso_url             = "${var.iso_server}${var.iso_name}"
  output_directory    = "../../workspace/packer-el9-x86_64-vmware"
  ovftool_options     = ["--noImageFiles", "--noNvramFile", "--compress=3"]
  shutdown_command    = "/sbin/halt -h -p"
  shutdown_timeout    = "2m30s"
  ssh_password        = "eurolinux"
  ssh_port            = 22
  ssh_timeout         = "2h"
  ssh_username        = "root"
  version             = "16"
  vm_name             = "el9-x86_64-${var.image}.${var.builder_short}"
  vmx_data = {
    "annotation": "${var.description}"
  }
  vmx_data_post = {
    "numVCPUs" = "2"
  }
  vmx_template_path   = "templates/el9-vmware.vmx"
}

build {
  sources = ["source.qemu.libvirt", "source.virtualbox-iso.virtualbox", "source.vmware-iso.vmware_workstation"]

  provisioner "shell" {
    execute_command = "{{ .Vars }} bash '{{ .Path }}'"
    scripts         = ["scripts/common/update.sh"]
  }

  provisioner "shell" {
    expect_disconnect = true
    inline            = ["/usr/sbin/reboot"]
    valid_exit_codes  = [0, 2300218]
  }

  provisioner "shell" {
    execute_command = "{{ .Vars }} bash '{{ .Path }}'"
    pause_before    = "30s"
    scripts         = ["scripts/common/minimize_packages.sh", "scripts/common/remove_man_pages.sh", "scripts/common/sshd.sh", "scripts/common/vmtools.sh", "scripts/extras/${var.image}.sh", "scripts/common/cleanup.sh", "scripts/common/minimize.sh"]
  }

  post-processors {
    post-processor "checksum" {
      checksum_types = ["sha1", "sha512"]
      output = "el9-x86_64-${var.image}.${var.builder_short}.{{.ChecksumType}}sum"
      keep_input_artifact = true
    }
    post-processor "shell-local" {
      environment_vars = ["SHASUM=el9-x86_64-${var.image}.${var.builder_short}.sha512sum"]
      inline = [
        "OVA=$(grep '.ova' $SHASUM)",
        "echo $OVA > $SHASUM"
      ]
      only = ["vmware-iso.vmware_workstation"]
    }
  }
}
