# Smart Household Agenda

**Smart Household Agenda** is a desktop-based personal dashboard built with Electron and React. It runs on a Raspberry Pi or laptop, showing your household agenda with calendar events, weather, and news updates.

## Scope and Vision

The goal is to build a smart agenda for home use. Eventually the app will:
- Display upcoming calendar events.
- Show current weather and a forecast.
- List the latest news headlines.
- Run automatically on a Raspberry Pi connected to a display.

Phase 1 sets up the project structure and a basic "Hello World" app.

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

A window should appear showing "Hello, Smart Household Agenda!".

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
