# Firebase push notifications

The application uses Firebase Cloud Messaging (FCM) for device push delivery.

## Flutter configuration

Copy `.env.example` to `.env` and fill these Firebase project values:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_ANDROID_API_KEY`
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_IOS_API_KEY`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_STORAGE_BUCKET` when the Firebase project exposes one

These are Firebase client configuration values. They are not server credentials.

The Flutter application initializes Firebase from the environment configuration, asks for notification permission after authentication, registers the Firebase Installation ID (FID) with the ERP API, and listens for FID rotation.

## Backend configuration

Set these environment variables for Django and the Celery worker/beat processes:

- `FIREBASE_ENABLED=true`
- `FIREBASE_PROJECT_ID=<project id>`
- `FCM_ANDROID_CHANNEL_ID=erp_notifications`
- `FIREBASE_CREDENTIALS_FILE=<path to the Firebase Admin service-account JSON>` when using a mounted credential file

Alternatively, leave `FIREBASE_CREDENTIALS_FILE` empty and provide Google Application Default Credentials through `GOOGLE_APPLICATION_CREDENTIALS` or the hosting platform's workload identity.

Never commit the Firebase Admin service-account JSON file.

## Android

Android 13+ requires notification permission. The app declares `POST_NOTIFICATIONS` and requests the permission after authentication.

## iOS

In the Firebase project, configure an APNs authentication key for the iOS app and enable Push Notifications in the Runner target's Apple capabilities/signing configuration. These settings depend on the Apple Developer team and provisioning profile, so they are intentionally not hard-coded into this repository.

## Delivery architecture

Business events create durable in-app notifications in Django. After the transaction commits, Celery asynchronously sends the push through FCM. Push delivery is tracked per notification/device and retries transient failures. Successfully delivered devices are not sent the same notification again on retry.

The Flutter app also handles foreground presentation and notification taps. The Notification Center remains the durable source visible inside the ERP, so push delivery is an accelerator, not the source of truth.
