# Hearth AI Privacy Policy

**Last updated:** March 9, 2026

## Overview

Privacy is a core principle of Hearth AI. All AI processing occurs on your device. No data leaves your device.

## Data Collection

**Hearth AI collects no data.** We do not collect, store, transmit, or share personal information, usage data, analytics, or telemetry of any kind.

## On-Device Processing

- All AI model inference runs locally on your device with on-device hardware acceleration.
- The app stores your conversations, documents, and memories only on your device with Apple's SwiftData framework.
- The app downloads model files (GGUF format) directly from Hugging Face Hub to your device. We do not proxy, log, or monitor these downloads.

## Network Usage

Hearth AI makes only these network requests:
- **Model browsing:** Requests to the Hugging Face Hub API to browse and search available models.
- **Model downloads:** Direct downloads of model weight files from Hugging Face Hub.

No network request contains user data, conversations, or personal information.

## Third-Party Services

Hearth AI connects to [Hugging Face Hub](https://huggingface.co) only for model discovery and model downloads. We have no control over the privacy practices of Hugging Face. Refer to [Hugging Face's Privacy Policy](https://huggingface.co/privacy) for details.

## Data Storage

The app stores all app data (conversations, documents, memories, and downloaded models) locally on your device. The main app and the Share Extension share data through an App Group container. This data does not leave your device.

## Children's Privacy

Hearth AI does not collect data from any users, and this includes children.

## Changes to This Policy

If we update this policy, we will post the new version here with a new date.

## Contact

If you have questions about this privacy policy, open an issue on our [GitHub repository](https://github.com/jtdub/hearth-ai-app).
