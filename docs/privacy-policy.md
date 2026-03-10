# Hearth AI Privacy Policy

**Last updated:** March 9, 2026

## Overview

Hearth AI is designed with privacy as a core principle. All AI processing happens entirely on your device. No data ever leaves your device.

## Data Collection

**Hearth AI collects no data.** We do not collect, store, transmit, or share any personal information, usage data, analytics, or telemetry of any kind.

## On-Device Processing

- All AI model inference runs locally on your device using on-device hardware acceleration.
- Your conversations, documents, and memories are stored only on your device using Apple's SwiftData framework.
- Model files (GGUF format) are downloaded directly from Hugging Face Hub to your device. We do not proxy, log, or monitor these downloads.

## Network Usage

The only network requests Hearth AI makes are:
- **Browsing models:** Requests to the Hugging Face Hub API to browse and search available models.
- **Downloading models:** Direct downloads of model weight files from Hugging Face Hub.

No user data, conversations, or personal information is included in any network request.

## Third-Party Services

Hearth AI connects to [Hugging Face Hub](https://huggingface.co) solely for model discovery and download. We have no control over Hugging Face's privacy practices. Please refer to [Hugging Face's Privacy Policy](https://huggingface.co/privacy) for details.

## Data Storage

All app data (conversations, documents, memories, and downloaded models) is stored locally on your device. Data is shared between the main app and the Share Extension via an App Group container, but never leaves your device.

## Children's Privacy

Hearth AI does not collect any data from any users, including children.

## Changes to This Policy

If we update this policy, we will post the revised version here with an updated date.

## Contact

If you have questions about this privacy policy, please open an issue on our [GitHub repository](https://github.com/jtdub/hearth-ai-app).
