# Smart Household Agenda

> The open-source, cross-platform command center for your home. Built with Flutter to unify your family's planning, chores, meals, and smart devices onto a single, ambient display.

---

[![Flutter Version](https://img.shields.io/badge/Flutter-3.13%2B-blue.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Build Status](https://img.shields.io/github/actions/workflow/status/your-username/smart-household-agenda/main.yml?branch=main)](https://github.com/your-username/smart-household-agenda/actions)
[![Open Issues](https://img.shields.io/github/issues/your-username/smart-household-agenda)](https://github.com/your-username/smart-household-agenda/issues)

---

## Table of Contents

1.  [**Project Overview**](#-project-overview)
    -   [The Problem](#the-problem)
    -   [The Solution](#the-solution)
    -   [Target Audience](#target-audience)
2.  [**Features in Detail**](#-features-in-detail)
    -   [Tier 1: Core Household Management](#tier-1-core-household-management)
    -   [Tier 2: Enhanced Coordination](#tier-2-enhanced-coordination)
    -   [Tier 3: Integrations & Enhancements](#tier-3-integrations--enhancements)
3.  [**Smart Integrations Ecosystem**](#-smart-integrations-ecosystem)
4.  [**Architectural Overview**](#-architectural-overview)
    -   [State Management](#state-management)
    -   [Backend & Database](#backend--database)
    -   [Project Structure](#project-structure)
5.  [**💻 Tech Stack & Key Packages**](#-tech-stack--key-packages)
6.  [**🚀 Getting Started (Developer Guide)**](#-getting-started-developer-guide)
    -   [Prerequisites](#prerequisites)
    -   [Configuration](#configuration)
    -   [Installation & Running](#installation--running)
    -   [Running Tests](#running-tests)
7.  [**🥧 Deployment Guide**](#-deployment-guide)
    -   [Raspberry Pi (Primary Target)](#raspberry-pi-primary-target)
    -   [Mobile (iOS & Android)](#mobile-ios--android)
    -   [Desktop & Web](#desktop--web)
8.  [**🗺️ Development Roadmap**](#️-development-roadmap)
9.  [**🤝 Contributing**](#-contributing)
10. [**License**](#-license)
11. [**Acknowledgments**](#-acknowledgments)

---

## 📖 Project Overview

### The Problem

Modern household management is fragmented. We use separate apps for calendars, to-do lists, grocery lists, and smart home control. This creates digital noise and makes it difficult to get a single, clear picture of what's happening at home. Questions like "Did anyone pick up milk?", "Who's on dinner duty tonight?", or "What time is soccer practice?" require checking multiple sources, leading to miscommunication and mental overhead.

### The Solution

**Smart Household Agenda** is an all-in-one solution that consolidates all aspects of home management into a single, intuitive interface. It's designed to be displayed on an "ambient screen"—an always-on tablet or monitor (ideally powered by a Raspberry Pi) placed in a central location like the kitchen. This provides a persistent, at-a-glance dashboard for the entire household, while also being fully functional as a mobile and desktop app.

### Target Audience

This application is designed for families, roommates, and anyone in a shared living situation who wants to improve coordination, reduce friction in daily tasks, and create a more connected and efficient home environment.

---

## ✨ Features in Detail

### Tier 1: Core Household Management

#### ✅ Shared Task & Chore Management
-   **User Stories:**
    -   *As a parent, I want to assign recurring chores to my kids and track their completion to teach responsibility.*
    -   *As a roommate, I want a fair way to distribute and visualize tasks so everyone does their part.*
-   **Detailed Functionality:**
    -   **Creation & Assignment:** Create tasks with titles, detailed descriptions, assignees (one or multiple), and due dates.
    -   **Sub-tasks:** Break down larger tasks (e.g., "Clean Kitchen") into smaller, checkable items.
    -   **Recurring Schedules:** Powerful scheduling engine (e.g., daily, every Tuesday/Thursday, first day of the month, etc.).
    -   **Priority Levels:** Tag tasks as Low, Medium, High, or Urgent.
    -   **Points & Rewards System:** Gamify chores by assigning points to tasks, with a leaderboard to encourage participation.
    -   **Completion Verification:** Optional photo attachments to confirm a task is done.
    -   **History & Log:** A persistent log of all completed tasks, filterable by person and date.

#### 🛒 Shared Shopping List
-   **User Stories:**
    -   *As a family member, I want to add an item to the list the moment I realize we're out, knowing it will be instantly visible to whoever shops next.*
-   **Detailed Functionality:**
    -   **Real-time Sync:** Uses a cloud database (Firestore) for instantaneous updates across all devices.
    -   **Smart Categorization:** Automatically groups items into categories (Produce, Dairy, etc.) to streamline the shopping trip. Users can also create custom categories.
    -   **Add by Voice/Barcode Scan:** Integrate voice-to-text and camera barcode scanning for rapid item entry.
    -   **Item Details:** Add quantity, notes (e.g., "get the low-sodium version"), and even price estimates.
    -   **"In-Cart" Mode:** Tap an item to move it to a temporary "in the cart" section, keeping the main list clean while you shop.
    -   **Recipe Integration:** Directly add all ingredients from a recipe in the Meal Planner to the list.

### Tier 2: Enhanced Coordination

#### 📅 Family Calendar Integration
-   **User Stories:**
    -   *As a household, we want to see everyone's key appointments in one place to avoid scheduling conflicts.*
-   **Detailed Functionality:**
    -   **Two-Way Sync:** Connect with external calendars (Google Calendar, Apple iCloud) for a unified view. Events created in the app can be pushed to personal calendars.
    -   **Color-Coding & Filtering:** Automatically assign a color to each family member and allow filtering the view to see only specific schedules.
    -   **Event Types:** Create custom event categories (e.g., Appointment, Birthday, Sports, Family Event) with unique icons.
    -   **Travel Time Alerts:** Integrate with mapping services to provide "time to leave" notifications for events with a location.

#### 🍽️ Meal Planning
-   **User Stories:**
    -   *As the primary cook, I want to plan the week's meals in advance to reduce daily stress and shop more efficiently.*
-   **Detailed Functionality:**
    -   **Visual Weekly Grid:** Drag-and-drop interface to plan breakfast, lunch, and dinner for the entire week.
    -   **Recipe Book:** A central database for family recipes. Manually enter recipes or import them from popular websites via URL.
    -   **Dietary & Nutritional Info:** Tag recipes (Vegetarian, Gluten-Free, etc.) and automatically pull basic nutritional information.
    -   **Ingredient Scaling:** Automatically adjust ingredient quantities based on the number of servings needed.

### Tier 3: Integrations & Enhancements

#### 💡 Other Planned Features
-   **Household Budget Tracker:** Simple expense logging for shared costs (e.g., utilities, rent, groceries) with a "who owes who" calculator.
-   **Digital Whiteboard/Sticky Notes:** A shared canvas for quick notes, doodles, and messages.
-   **Document & Info Hub:** A secure place to store important household information (WiFi passwords, emergency contacts, manuals).

---

## 🔌 Smart Integrations Ecosystem

This app aims to be a true hub by connecting to popular services and smart home platforms.

-   **Google Home / Assistant:**
    -   **API:** Google Smart Device Management (SDM) API.
    -   **Capabilities:** Display live status of thermostats, cameras, and locks. Trigger Google Assistant Routines directly from the dashboard.
-   **Philips Hue:**
    -   **API:** Philips Hue Entertainment API v2.
    -   **Capabilities:** Full control of lights, groups, and scenes. Create dynamic "lighting atmospheres" that sync with family events (e.g., a "Movie Night" scene).
-   **Spotify:**
    -   **API:** Spotify Web API.
    -   **Capabilities:** Display the currently playing song on any device in the home. Basic playback controls (play/pause/skip).
-   **Location-Specific (Netherlands):**
    -   **Albert Heijn:** Display weekly "Bonus" offers. Sync the shopping list with the AH app. *Note: As of Oct 2025, this requires a community-maintained, reverse-engineered API and may be unstable.*
    -   **Buienradar / GVB / NS:** Integrate real-time rain radar and public transport departure times for the household's location in Amsterdam.
    -   **Waste Collection Calendar (Afvalkalender):** API integration with the local municipality to display upcoming trash/recycling pickup days.

---

## 🏛️ Architectural Overview

### State Management
The project will use **BLoC (Business Logic Component)** for state management. This choice promotes a clean separation of concerns between UI, business logic, and data layers, making the app highly scalable and testable.

### Backend & Database
**Firebase** will serve as the backend for its robust, real-time capabilities.
-   **Firestore:** For real-time synchronization of tasks, shopping lists, and calendar events across all user devices.
-   **Firebase Authentication:** For secure user profiles and household management.
-   **Cloud Storage for Firebase:** For storing user-uploaded images (e.g., recipe photos, task verification).

### Project Structure
The project follows a feature-first, layered architecture for scalability.
```

lib/
├── app/                  \# App-level widgets, routing, themes
├── core/                 \# Core logic, services, utilities (API clients, DB handlers)
├── features/             \# Each feature has its own folder
│   ├── tasks/
│   │   ├── bloc/         \# BLoCs and events/states for tasks
│   │   ├── data/         \# Repositories, data sources, models
│   │   └── presentation/ \# Widgets, pages specific to tasks
│   ├── shopping\_list/
│   └── ...
└── shared/               \# Shared widgets, models, constants used across features

````
---

## 💻 Tech Stack & Key Packages

-   **Framework:** Flutter 3.13+
-   **Language:** Dart 3.1+
-   **State Management:** `flutter_bloc`, `provider`
-   **Backend & Database:** `firebase_core`, `cloud_firestore`, `firebase_auth`
-   **Routing:** `go_router`
-   **Networking:** `http`, `dio`
-   **Local Storage:** `shared_preferences` for simple key-value storage.
-   **Testing:** `bloc_test`, `mocktail`
-   **Utilities:** `intl` for localization, `equatable` for model comparison.

---

## 🚀 Getting Started (Developer Guide)

### Prerequisites
1.  **Flutter SDK:** Version 3.13 or higher.
2.  **IDE:** Visual Studio Code (recommended) or Android Studio.
3.  **Firebase Project:** Create a new project on the [Firebase Console](https://console.firebase.google.com/).
4.  **Firebase CLI:** Install the `firebase-tools` CLI.

### Configuration
1.  **Clone the Repository:**
    ```sh
    git clone [https://github.com/your-username/smart-household-agenda.git](https://github.com/your-username/smart-household-agenda.git)
    cd smart-household-agenda
    ```
2.  **Set up Firebase:**
    -   Run `flutterfire configure` to connect your local project to your Firebase project.
    -   Enable Authentication (Email/Password, Google) and Firestore in the Firebase Console.
3.  **Environment Variables:**
    -   Create a file named `.env` in the root of the project.
    -   Copy the contents of `.env.example` into `.env`.
    -   Fill in the required API keys for third-party services (e.g., Google Maps, Spoonacular).
    ```
    # .env.example
    SPOONACULAR_API_KEY=your_api_key_here
    GOOGLE_MAPS_API_KEY=your_api_key_here
    ```

### Installation & Running
1.  **Get Dependencies:**
    ```sh
    flutter pub get
    ```
2.  **Run the App:**
    ```sh
    flutter run
    ```

### Running Tests
Execute the full test suite (unit, widget, and integration tests):
```sh
flutter test
````

-----

## 🥧 Deployment Guide

### Raspberry Pi (Primary Target)

The app is optimized for running in kiosk mode on a Raspberry Pi 4 (or newer) with an official touchscreen or external monitor.

1.  **Build the Linux Executable:**
    ```sh
    flutter build linux --release
    ```
2.  **Set up `systemd` Service:** Create and enable the service file as detailed in the [abridged README](https://www.google.com/search?q=./README_short.md) to have the app launch automatically on boot. Ensure you are running a desktop environment on your Raspberry Pi OS.

### Mobile (iOS & Android)

Standard build and deployment process for Flutter apps.

1.  Follow the official Flutter documentation for code signing (iOS) and generating a signed APK/AAB (Android).
2.  Build the release version:
    ```sh
    flutter build ipa --release
    flutter build appbundle --release
    ```

### Desktop & Web

  - **Desktop (Windows, macOS):** Use `flutter build <platform>` to create executables. Consider using tools like `msix` (Windows) or creating a DMG (macOS) for distribution.
  - **Web:** Build the app using `flutter build web` and deploy the contents of the `/build/web` directory to any static web host, such as Firebase Hosting.

-----

## 🗺️ Development Roadmap

  - **Q4 2025 (In Progress):**
      - [ ] Finalize Core Features (Tasks, Shopping List).
      - [ ] Implement Firebase backend and authentication.
      - [ ] Develop initial Raspberry Pi deployment script.
  - **Q1 2026:**
      - [ ] Develop and integrate Family Calendar feature.
      - [ ] Begin work on Meal Planner and Recipe Book.
      - [ ] Public alpha release.
  - **Q2 2026:**
      - [ ] Integrate Philips Hue and Google Home APIs.
      - [ ] Develop mobile-specific UI optimizations.
      - [ ] Set up CI/CD pipeline for automated builds.
  - **Future:**
      - [ ] Explore additional third-party integrations (Spotify, etc.).
      - [ ] Add budget tracking and document hub features.
      - [ ] Internationalization and localization.

-----

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

Please follow these steps:

1.  Fork the Project.
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4.  Adhere to the `effective_dart` code style.
5.  Add tests for your new feature.
6.  Push to the Branch (`git push origin feature/AmazingFeature`).
7.  Open a Pull Request.

-----

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

-----

## 🙏 Acknowledgments

  - The Flutter Team for creating an amazing framework.
  - The open-source community for providing invaluable packages.
  - You, for considering and contributing to this project.

<!-- end list -->
