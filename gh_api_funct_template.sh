create_release() {
    curl -L \
      -X POST \
      -H "Authorization: Bearer $GH_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -d '{"tag_name":"$GH_TAG","target_commitish":"$GH_BRANCH","name":"$GH_RELEASE","body":"$GH_RELEASE_BODY","draft":false,"prerelease":false,"generate_release_notes":true}' \
      "https://api.github.com/repos/$OWNER/$REPO/releases"
}

create_release_notes() {
    curl -L \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GH_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -d '{"tag_name":"$GH_TAG","target_commitish":"$GH_BRANCH","configuration_file_path":".github/release.yml"}' \
      https://api.github.com/repos/$OWNER/$REPO/releases/generate-notes
}

get_latest_release() {
    curl -L \
    -X GET \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$OWNER/$REPO/releases/latest
}

get_release_by_tag() {
    curl -L \
    -X GET \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$OWNER/$REPO/releases/tags/$GH_TAG
}

delete_release_asset() {
    curl -L \
    -X DELETE \
    -s -w "%{http_code}" \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$OWNER/$REPO/releases/assets/$ASSET_ID
}

list_release_assets() {
    curl -L \
    -X GET \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$OWNER/$REPO/releases/$RELEASE_ID/assets
  }

upload_release_asset() {
    curl -L \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GH_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/octet-stream" \
      -T "$BOX_BASE_PATH/$ASSET_FILENAME" \
      "https://uploads.github.com/repos/$OWNER/$REPO/releases/$RELEASE_ID/assets?name=$ASSET_NAME"
}

update_release_asset() {
    curl -L \
    -X PATCH \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d '{"name":"$ASSET_NAME","label":"$ASSET_NAME"}' \
    https://api.github.com/repos/$OWNER/$REPO/releases/assets/$ASSET_ID
}