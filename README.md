# Smart Household Agenda

**Smart Household Agenda** is a desktop-based personal dashboard built with Electron and React. It runs on a Raspberry Pi or laptop, showing your household agenda with calendar events, weather, and news updates.

## Scope and Vision

The goal is to build a smart agenda for home use. Eventually the app will:
- Display upcoming calendar events.
- Show current weather and a forecast.
- List the latest news headlines.
- Run automatically on a Raspberry Pi connected to a display.

The initial phase set up the project structure with a simple "Hello World" app.
The app now fetches events from a public calendar feed and lists upcoming
entries in the main window.

## Prioritized Feature Map

1. **Calendar Events Display** – High priority.
2. **Weather Forecast** – High priority.
3. **News Headlines** – Medium priority.
4. **Configuration UI** – Lower priority.
5. **Startup/Autorefresh** – Medium priority.

## Getting Started

### Prerequisites

- Node.js and npm installed.

### Installation

```bash
npm install
```

### Running the Application

```bash
npm start
```

A window should appear listing upcoming calendar events.

### Running in Visual Studio Code

1. Open the folder in VS Code.
2. Choose **Run Electron** in the Run and Debug panel.
3. Start debugging; dependencies will install automatically.

## Project Structure

```
├── electron/
│   ├── main.js
│   └── preload.js
├── src/
│   ├── components/
│   ├── pages/
│   ├── index.html
│   └── index.jsx
├── .gitignore
├── package.json
└── README.md
```

## Deployment Notes

When deploying to a Raspberry Pi, you can use a systemd service to start the app on boot. Updates can be pulled from git and the service restarted.
