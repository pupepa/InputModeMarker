# アップデート版の配布手順

あAマーカーをDeveloper IDで署名し、公証済みDMGとしてGitHub Releasesに公開する手順です。初回の0.1.0配布で確認した方法を記載しています。

以下では **0.1.1／ビルド番号2** を例にします。実際に公開する番号へ置き換えてください。

## 1. 配布環境を確認する

- XcodeとGitHub CLI（`gh`）がインストール済
- XcodeのApple AccountとTeamが設定済
- キーチェーンに秘密鍵付きのDeveloper ID Application証明書がある
- 公証用キーチェーンプロファイル `InputModeMarker-notary` が登録済
- GitHubの `pupepa/InputModeMarker` にpush・Release作成できる

プロジェクトのルートで実行します。

```bash
git status --short
git remote -v
gh auth status
security find-identity -v -p codesigning
```

このプロジェクトの配布設定は次のとおりです。

| 項目 | 値 |
| --- | --- |
| リポジトリ | `pupepa/InputModeMarker` |
| Scheme | `InputModeMarker`（共有Scheme） |
| アプリ名 | `あAマーカー.app` |
| Bundle ID | `com.minimalab.InputModeMarker` |
| Team ID | `BGN2M6CRN8` |
| 署名証明書 | ローカルにあるDeveloper ID Application証明書 |
| 公証プロファイル | `InputModeMarker-notary` |
| 対応OS | macOS 26.2以降 |
| 対応CPU | Apple Silicon／Intel（Universal） |

証明書を更新した場合や別のMacで作業する場合は、有効な証明書名と認証情報を再確認してください。秘密鍵やパスワードはGitへ登録しません。

## 2. VersionとBuildを更新する

Xcodeで `InputModeMarker.xcodeproj` を開き、**TARGETS → InputModeMarker → General** で変更します。

- Version：`0.1.1`
- Build：`2`（前回より増やす）

DebugとReleaseの両構成に反映されていることを確認します。

配布設定も確認してください。

- macOS Deployment Target：`26.2`
- Architectures：Standard Architectures（Apple Silicon、Intel）
- ReleaseのBuild Active Architecture Only：`No`
- Hardened Runtime：有効
- App Sandbox：有効
- Archiveに使う構成：Release

変更内容の動作確認を行い、公開するソースと設定をコミットします。

```bash
git diff
git add InputModeMarker InputModeMarker.xcodeproj
git diff --cached
git commit -m "Prepare version 0.1.1"
git status --short
```

READMEなども変更した場合は、そのファイルもコミットに含めます。作業ツリーがクリーンになってからビルドしてください。

## 3. 作業用変数を設定する

以降のコマンドは、同じターミナルで順番に実行します。途中でターミナルを閉じた場合は、既存の作業ディレクトリを指定して変数を復元してください。

```bash
RELEASE_VERSION="0.1.1"
RELEASE_TAG="v${RELEASE_VERSION}"
RELEASE_REPO="pupepa/InputModeMarker"
RELEASE_IDENTITY="YOUR_CERTIFICATE_SHA1"
RELEASE_NOTARY_PROFILE="InputModeMarker-notary"
RELEASE_SOURCE_COMMIT="$(git rev-parse HEAD)"
RELEASE_WORK_DIR="$PWD/build/release-${RELEASE_VERSION}-$(date +%Y%m%d-%H%M%S)"
RELEASE_DIST_DIR="$PWD/dist"
RELEASE_DMG="$RELEASE_DIST_DIR/InputModeMarker-${RELEASE_VERSION}.dmg"
RELEASE_APP="$RELEASE_WORK_DIR/export/あAマーカー.app"

mkdir -p "$RELEASE_WORK_DIR" "$RELEASE_DIST_DIR"
```

`YOUR_CERTIFICATE_SHA1` は、`security find-identity -v -p codesigning` に表示されたDeveloper ID Application証明書のSHA-1ハッシュへ置き換えます。証明書の個人名をドキュメントへ記載する必要はありません。

同じバージョンの公開済みタグやDMGがある場合は、上書きせず、公開するバージョンを見直します。未公開の作業をやり直す場合は、古いDMGを別の場所へ移してから作成してください。

## 4. Release Archiveを作成する

```bash
xcodebuild archive \
  -project InputModeMarker.xcodeproj \
  -scheme InputModeMarker \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$RELEASE_WORK_DIR/InputModeMarker.xcarchive" \
  -derivedDataPath "$RELEASE_WORK_DIR/DerivedData"
```

`ARCHIVE SUCCEEDED` を確認します。失敗した場合は、原因を直してから先へ進んでください。

ArchiveとdSYMは、公開したバージョンの調査に使えるよう保管します。`build/` と `dist/` はGitの管理対象外です。

## 5. Developer ID署名済みアプリをエクスポートする

作業ディレクトリにExportOptionsを作成します。

```bash
cat > "$RELEASE_WORK_DIR/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>BGN2M6CRN8</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Developer ID Application</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$RELEASE_WORK_DIR/InputModeMarker.xcarchive" \
  -exportPath "$RELEASE_WORK_DIR/export" \
  -exportOptionsPlist "$RELEASE_WORK_DIR/ExportOptions.plist"
```

`EXPORT SUCCEEDED` を確認します。このplistでは証明書種別を指定し、Xcodeが指定Teamの有効な証明書を選択します。DMG署名では `RELEASE_IDENTITY` に設定したSHA-1ハッシュで証明書を指定します。

**Archive内のアプリを直接配布せず、エクスポートしたアプリを使います。** エクスポート時に配布用の署名と権限へ整えられます。

## 6. アプリを検証する

```bash
lipo -archs "$RELEASE_APP/Contents/MacOS/あAマーカー"
codesign --verify --deep --strict --verbose=2 "$RELEASE_APP"
codesign -dv --verbose=4 "$RELEASE_APP"
codesign -d --entitlements - "$RELEASE_APP"
plutil -p "$RELEASE_APP/Contents/Info.plist"
```

### 確認する内容

- `lipo` に `arm64` と `x86_64` の両方が表示される
- 署名検証が成功する
- `Authority` がDeveloper ID Applicationである
- 署名の `flags` に `runtime` が含まれる
- `Timestamp` がある
- App Sandboxの権限が有効である
- `com.apple.security.get-task-allow` がない、またはfalseである
- `CFBundleShortVersionString` と `CFBundleVersion` が今回の番号である
- `LSMinimumSystemVersion` が `26.2` である

署名には `codesign --deep` を使って上書きせず、配布用エクスポートをやり直します。上の `--deep` は検証用です。

## 7. DMGを作成して署名する

```bash
mkdir -p "$RELEASE_WORK_DIR/dmg-root"

ditto "$RELEASE_APP" "$RELEASE_WORK_DIR/dmg-root/あAマーカー.app"
ln -s /Applications "$RELEASE_WORK_DIR/dmg-root/Applications"

hdiutil create \
  -volname "あAマーカー ${RELEASE_VERSION}" \
  -srcfolder "$RELEASE_WORK_DIR/dmg-root" \
  -format UDZO \
  -o "$RELEASE_DMG"

codesign \
  --sign "$RELEASE_IDENTITY" \
  --timestamp \
  --identifier com.minimalab.InputModeMarker.dmg \
  "$RELEASE_DMG"
```

DMGには、署名済みアプリとApplicationsへのリンクを収録します。作業を再開するときは、すでにあるリンクに対して `ln -s` を再実行しないでください。

## 8. DMGを公証に送信する

```bash
xcrun notarytool submit "$RELEASE_DMG" \
  --keychain-profile "$RELEASE_NOTARY_PROFILE" \
  --wait
```

Submission IDを控え、**`status: Accepted` を確認してから**先へ進みます。コマンドの終了だけで成功と判断しないでください。

待機を中断した場合は、同じSubmission IDで状態を確認します。

```bash
xcrun notarytool info "SUBMISSION_ID" \
  --keychain-profile "$RELEASE_NOTARY_PROFILE"
```

`Invalid` の場合はログを取得します。

```bash
xcrun notarytool log "SUBMISSION_ID" \
  --keychain-profile "$RELEASE_NOTARY_PROFILE" \
  "$RELEASE_WORK_DIR/notarization-log.json"
```

原因を修正し、必要なコミット・ビルド・エクスポート・DMG作成をやり直して再送信します。失敗したDMGは公開しません。

## 9. 公証証明を添付して最終検証する

```bash
xcrun stapler staple "$RELEASE_DMG"
xcrun stapler validate "$RELEASE_DMG"
codesign --verify --verbose=2 "$RELEASE_DMG"
hdiutil verify "$RELEASE_DMG"
spctl --assess --type open \
  --context context:primary-signature \
  --verbose=2 "$RELEASE_DMG"
```

各検証の成功と、Gatekeeperの `accepted`／`source=Notarized Developer ID` を確認します。

公証・証明添付後にアプリやDMGの内容を編集すると、作り直しが必要です。

最終DMGのチェックサムを作成します。**証明添付後**に実行してください。

```bash
(
  cd "$RELEASE_DIST_DIR" || exit 1
  shasum -a 256 "InputModeMarker-${RELEASE_VERSION}.dmg" \
    > "InputModeMarker-${RELEASE_VERSION}.dmg.sha256"
  shasum -a 256 -c "InputModeMarker-${RELEASE_VERSION}.dmg.sha256"
)
```

## 10. Gitタグを付けてpushする

```bash
git status --short
git rev-parse HEAD
printf '%s\n' "$RELEASE_SOURCE_COMMIT"
```

作業ツリーがクリーンで、HEADがビルド前に記録したコミットと一致することを確認します。ソースや設定を変更した場合は、変更をコミットして配布物も作り直してください。

タグが未作成なら次を実行します。

```bash
git tag -a "$RELEASE_TAG" -m "Release ${RELEASE_VERSION}"
git push -u origin main
git push origin "$RELEASE_TAG"
```

すでにローカルタグを作成済みなら、その参照先を確認し、タグ作成を省略します。

```bash
git rev-parse "${RELEASE_TAG}^{commit}"
```

公開済みタグを別のコミットへ付け替えず、新しいバージョンを作成してください。

## 11. Release下書きを作成して公開する

変更内容・対応環境・インストール方法を記載したリリースノートを、作業ディレクトリの `release-notes.md` に保存します。

### 例

```markdown
あAマーカー 0.1.1

変更内容：
- 今回の変更内容を記載

対応環境：macOS 26.2以降、Apple Silicon／Intel。

AssetsからDMGをダウンロードし、アプリをApplicationsへコピーしてください。
Developer ID署名・Apple公証済みです。
```

実機での確認状況や既知の問題も、必要に応じて記載します。

```bash
gh release create "$RELEASE_TAG" \
  "$RELEASE_DMG" \
  "${RELEASE_DMG}.sha256" \
  --repo "$RELEASE_REPO" \
  --verify-tag \
  --title "あAマーカー ${RELEASE_VERSION}" \
  --notes-file "$RELEASE_WORK_DIR/release-notes.md" \
  --draft

gh release view "$RELEASE_TAG" \
  --repo "$RELEASE_REPO" \
  --json tagName,isDraft,name,body,assets
```

タグ、説明文、DMGとチェックサムの添付を確認します。アップロードされたDMGの `digest` が、ローカルのSHA-256と一致することも確認してください。

確認後、公開します。

```bash
gh release edit "$RELEASE_TAG" \
  --repo "$RELEASE_REPO" \
  --draft=false \
  --latest

gh release view "$RELEASE_TAG" \
  --repo "$RELEASE_REPO" \
  --json url,isDraft,assets
```

試用版として配布する場合は、下書き作成時に `--prerelease` を追加し、公開時の `--latest` は指定しません。通常版か試用版かは、公開前に決めます。

## 12. 公開先からダウンロードして確認する

ブラウザで次のページを開き、DMGをダウンロードし直します。

```text
https://github.com/pupepa/InputModeMarker/releases
```

- Applicationsへコピーして起動できること
- インストールしたアプリのVersionが今回の番号であること
- 入力モード表示、移動、サイズ変更、背景色変更、終了が動くこと
- ログイン時の起動設定が動くこと
- 旧版を終了してから置き換えると、保存済み設定が期待どおり引き継がれること
- 可能ならApple Silicon／IntelそれぞれのMacで確認する

公証済みでも、初回起動時にインターネットからダウンロードしたアプリであることの確認が表示される場合があります。

## 公証認証情報を再登録する場合

キーチェーンの登録は毎回必要ではありません。別のMacを使う場合や認証情報を更新する場合は、Apple Accountの管理サイトでアプリ用パスワードを作成し、次を実行します。

```bash
xcrun notarytool store-credentials "InputModeMarker-notary" \
  --apple-id "Apple Accountのメールアドレス" \
  --team-id "BGN2M6CRN8"
```

求められたらアプリ用パスワードを入力します。パスワードをコマンド、ドキュメント、Gitへ書き込まないでください。

## 参考

- [Apple：配布用署名](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)
- [Apple：DMGの作成と配布](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Apple：公証フロー](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [GitHub：Releaseの作成・管理](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
