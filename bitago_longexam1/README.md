# Bitago Long Exam 1

Flutter implementation of the supplied long-exam screenshots.

## Run

```sh
flutter pub get
flutter run
```

Use a DummyJSON demo account, for example username `emilys` and password
`emilyspass`. An internet connection is required for sign-in, posts, and comments.

## Implemented requirements

- Required models, providers, screens, services, and reusable widgets.
- Screenshot dependency list and package name `bitago_longexam1`.
- Post model retains the screenshot fields and JSON fallbacks, with a title field
  for DummyJSON posts. PostService supports the screenshot pagination API.
- Real DummyJSON sign-in, profile persistence with SharedPreferences, and splash
  routing to sign-in or the home screen based on the saved user.
- News feed pagination, profile posts fetched by user ID, post detail with all
  comments, and adding comments with loading, empty, retry, and error states.
- Clickable post and comment likes stored separately for each user.
- Settings with persisted system/light/dark theme and sign-out that clears the
  session and navigation history.

## Assets

The app uses the supplied `assets/images/nuicon.jpeg` directly, as requested.
It replaces the PNG names in the screenshots. The course fonts and `owl.jpg`
were not supplied. The app uses system font fallbacks; the optional font
configuration is recorded in `pubspec.yaml` for when the originals are available.

## API behavior

DummyJSON simulates comment writes and does not persist them on its server.
Successfully submitted comments are therefore also saved locally per user and
post. Likes are local preferences; they do not change the public API's totals.
The saved session contains the user profile, not the password or access tokens.
This assignment restores local sign-in state; it does not authorize protected
server operations. Notifications have an empty state because the supplied API
has no notifications endpoint.

API references: https://dummyjson.com/docs/auth,
https://dummyjson.com/docs/posts, https://dummyjson.com/docs/comments.

## Verify

```sh
flutter analyze
flutter test
flutter build web
```
