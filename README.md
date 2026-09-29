# isusm-app

App for the ISU Soil Moisture Network.

## Workflow for making a release

- sh scripts/release.sh {major,minor,patch}
- Review the version and changelog, then commit and push a `v<version>` tag to trigger the iOS TestFlight upload.
- Manual uploads are also available from the GitHub Actions `iOS Release` workflow.
