# ZWEIDENKER Flutter Workflows

Workflows used at [ZWEIDENKER](https://zweidenker.de) to build and deploy Flutter Apps.

## Melos Quality Checks

```yaml
  quality:
    uses: zweidenker/flutter_workflows/.github/workflows/melos_quality_checks.yaml@v1
    with:
        setup: true
        lint: false
        test: true
```

Performs quality checks for repositories using [melos](https://github.com/invertase/melos)

### Inputs

| Name   | Type      | Description                              | Default       | required |
|--------|-----------|------------------------------------------|---------------|----------|
| setup  | `boolean` | Should run `melos run setup`             | true          |          |
| lint   | `boolean` | Should run `melos run lint:all`          | true          |          |
| test   | `boolean` | Should run `melos run test:coverage:all` | true          |          |
| runner | `string`  | Github actions runner                    | ubuntu-latest |          |
| lfs    | `boolean` | Enable git lfs                           | false         |          |



## Build Android

```yaml
  build_android:
    needs: quality
    uses: zweidenker/flutter_workflows/.github/workflows/build_android.yaml@v1
    with:
      appDirectory: packages/app
      buildApk: false
      buildBundle: true
      upload: ${{ github.ref_name == 'main' }}
    secrets:
      additionalBuildArguments: --dart-define=API_KEY=${{ secrets.API_KEY }}
      keyStore: ${{ secrets.ANDROID_KEYSTORE }}
      keyStorePassword: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
      keyPassword: ${{ secrets.ANDROID_KEY_PASSWORD }}
      keyAlias: ${{ secrets.ANDROID_KEY_ALIAS }}
      googleApiKey: ${{ secrets.GOOGLE_API_KEY }}
```

### Setup

In order to setup signing the app's `build.gradle` needs to contain the following blocks.

```gradle
...

def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
  keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
  ...

  signingConfigs {
    release {
      keyAlias keystoreProperties['keyAlias']
      keyPassword keystoreProperties['keyPassword']
      storeFile file(keystoreProperties['storeFile'])
      storePassword keystoreProperties['storePassword']
    }
  }
 
  ...
}
```

Also in `/path/to/app/android/fastlane/Fastfile` there should be the following lane
```ruby
  desc "Deploy App to Internal Google Play Track"
  lane :uploadApp do |options|
    supply(
        aab: "../build/app/outputs/bundle/release/app-release.aab",
        json_key_data: ENV['GOOGLE_UPLOAD_KEY'],
        track: "internal"
    )
  end
```
> **:warning: Note that `GOOGLE_UPLOAD_KEY` is accessed using `ENV` and not through `options`**


### Inputs

| Name              | Type      | Description                                                                                                                                                                                                                                    | Default       | required |
|-------------------|-----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------|----------|
| appDirectory      | `string`  | Directory where the app is based on the repository root. eg `packages/app`                                                                                                                                                                     |               | *        |
| buildApk          | `boolean` | Should build an Apk                                                                                                                                                                                                                            | true          |          |
| buildBundle       | `boolean` | Should build an App Bundle                                                                                                                                                                                                                     | true          |          |
| upload            | `boolean` | Should upload the App to Google Play. Note this will also check if the current workflow does **not** run on a pull_request event                                                                                                               | false         |          |
| archiveArtifacts  | `boolean` | If the workflow should archive apks and aabs. This normally should only be needed for a first release build to upload manually to Google Play or for certain PRs                                                                               | false         |          |
| runner            | `string`  | Github actions runner                                                                                                                                                                                                                          | ubuntu-latest |          |
| lfs               | `boolean` | Enable git lfs                                                                                                                                                                                                                                 | false         |          |
| buildNumberOffset | `number`  | An Offset used to generate the BuildNumber. This will result in the build number being the offset + the Run Number of Github. This is only required if there are already builds on the Play Store in order to have an increasing Build Number. | 0             |          |
### Secrets

| Name                     | Description                                                                                                                                                   | required |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| additionalBuildArguments | Arguments that will be appended to the `flutter build` command. e.g `--dart-define`                                                                           |          |
| keyStore                 | Android Signing Key. Encoded as a base64 String                                                                                                               | *        |
| keyStorePassword         | Keystore Password                                                                                                                                             | *        |
| keyPassword              | Key Password                                                                                                                                                  | *        |
| keyAlias                 | Key Alias                                                                                                                                                     | *        |
| googleApiKey             | Google Play Service Account json key used to upload. Information on how to optain this can be found [here](https://docs.fastlane.tools/actions/supply/#setup) |          |


## Build iOS

```yaml
  build_ios:
    uses: zweidenker/flutter_workflows/.github/workflows/build_ios.yaml@v1
    with:
      appDirectory: packages/app
      fastlaneEnv: app
      upload: ${{ github.ref_name == 'main' }}
    secrets:
      additionalBuildArguments: --dart-define=API_KEY=${{ secrets.API_KEY }}
      matchPassword: ${{ secrets.MATCH_PASSWORD }}
      apiKey: ${{ secrets.IOS_API_KEY }}
      matchSSHKey: ${{ secrets.MATCH_GIT_PRIVATE_KEY }}
```

### Setup

For the pipeline to work the following fastlane configurations must be met

There is a valid `Matchfile` under `path/to/app/ios/fastlane/Matchfile`

The following lanes are defined in `path/to/app/ios/fastlane/Fastfile`

```ruby

  lane :certificates do |options|
    setup_ci()
    api_key_path = ENV['IOS_API_KEY']
    match(
      type: "appstore",
      readonly: true
    )

  end

  desc "build app"
  lane :buildApp do |options|
    setup_ci()
    gym(
          export_options: "fastlane/export_options/app-store.plist",
          output_directory: 'build',
        )
  end

  desc "upload to testflight"
  lane :uploadApp do |options|
    upload_to_testflight(
      ipa: "build/Runner.ipa",
      api_key_path: ENV['IOS_API_KEY'],
      app_identifier: ENV['APP_IDENTIFIER'],
      skip_waiting_for_build_processing: true
    )
  end

```

> **:warning: Note that `IOS_API_KEY` is accessed using `ENV` and not through `options`**

> **:warning: Note that the `certificates` and `buildApp` lane  contain calls to `setup_ci()` to ensure proper keychain management**

### Inputs

| Name              | Type      | Description                                                                                                                                                                                                                                   | Default       | required |
|-------------------|-----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------|----------|
| appDirectory      | `string`  | Directory where the app is based on the repository root. eg `packages/app`                                                                                                                                                                    |               | *        |
| matchHost         | `string`  | Host that is used for fastlane match repository. This is needed, as ZWEIDENKER currently host our match repository on bitbucket                                                                                                               | bitbucket.org |          |
| fastlaneEnv       | `string`  | Fastlane Environment                                                                                                                                                                                                                          |               | *        |
| upload            | `boolean` | Should upload the App to Testflight. Note this will also check if the current workflow does **not** run on a pull_request event                                                                                                               | false         |          |
| runner            | `string`  | Github actions runner                                                                                                                                                                                                                         | macos-latest  |          |
| lfs               | `boolean` | Enable git lfs                                                                                                                                                                                                                                | false         |          |
| buildNumberOffset | `number`  | An Offset used to generate the BuildNumber. This will result in the build number being the offset + the Run Number of Github. This is only required if there are already builds on the App Store in order to have an increasing Build Number. | 0             |          |

| Name                     | Description                                                                                                                                              | required |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| additionalBuildArguments | Arguments that will be appended to the `flutter build` command. e.g `--dart-define`                                                                      |          |
| matchPassword            | Fastlane Match Password                                                                                                                                  | *        |
| apiKey                   | Apple Api Key as a unencoded json. The format can be found [here](https://docs.fastlane.tools/app-store-connect-api/#using-an-app-store-connect-api-key) | *        |
| matchSSHKey              | Private SSH Key to access the match repository                                                                                                           | *        |
