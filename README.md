\# Watchers



\*\*Watchers\*\* is a Flutter mobile app for tracking movies and TV shows with episode-level progress, cross-season logic, and TMDB metadata.



\## Features



\- Browse movies and TV shows via the TMDB API  

\- Track watched episodes with cross-season logic  

&#x20; - Mark an episode and all earlier released episodes as watched  

&#x20; - Unmark an episode and all later released episodes as unwatched  

\- Mark entire seasons as watched/unwatched  

\- Library with \*\*Planned\*\*, \*\*Watched\*\*, and \*\*Dropped\*\* statuses  

\- “Airing” view with episodes airing today and in the future  

\- Material 3 UI with dynamic color (Android)



\## Tech stack



\- \*\*Flutter\*\* (Dart)  

\- \*\*Riverpod\*\* for state management  

\- \*\*TMDB API\*\* for metadata (movies, TV shows, episodes, cast, trailers)  

\- Local JSON persistence for user data (library, watch progress)  



\## Running locally



```bash

\# Get dependencies

flutter pub get



\# Run on a connected device/emulator

flutter run

```



You will need your own TMDB API key and to configure it in the app’s network layer.



\## Project structure (high level)



\- `lib/providers/` – Riverpod notifiers and providers  

&#x20; - `tv\_progress\_provider.dart` – episode \& season progress logic  

&#x20; - `library\_provider.dart` – user’s movie/TV library  

&#x20; - `next\_airing\_provider.dart` – airing episodes logic  

\- `lib/screens/` – UI screens (home, movie details, TV details, episode details, etc.)  

\- `lib/models/` – data models (Movie, TvProgress, MediaLibraryItem, etc.)  

\- `lib/services/` – API clients and local persistence  



\## Screenshots



Screenshots can be added under a `screenshots/` folder and referenced here later.



\## License



This is a personal portfolio project. All rights reserved.

