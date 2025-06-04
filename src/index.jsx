import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';

function parseICS(text) {
  const events = [];
  const blocks = text.split('BEGIN:VEVENT').slice(1);
  for (const block of blocks) {
    const body = block.split('END:VEVENT')[0];
    const summary = (body.match(/SUMMARY:(.+)/) || [])[1];
    const start = (body.match(/DTSTART(?:;[^:]+)?:([^\n\r]+)/) || [])[1];
    const end = (body.match(/DTEND(?:;[^:]+)?:([^\n\r]+)/) || [])[1];
    if (summary && start) {
      events.push({ summary: summary.trim(), start: start.trim(), end: end ? end.trim() : '' });
    }
  }
  return events;
}

function CalendarEvents({ feedUrl }) {
  const [events, setEvents] = useState([]);

  useEffect(() => {
    async function load() {
      try {
        const resp = await fetch(feedUrl);
        const text = await resp.text();
        setEvents(parseICS(text).slice(0, 5));
      } catch (err) {
        console.error('Failed to load calendar events', err);
      }
    }
    load();
  }, [feedUrl]);

  return (
    <div>
      <h2>Upcoming Events</h2>
      <ul>
        {events.map((ev, idx) => (
          <li key={idx}>{`${ev.start} - ${ev.summary}`}</li>
        ))}
      </ul>
    </div>
  );
}

const rootElem = document.getElementById('root');

const App = () => (
  <CalendarEvents feedUrl="https://calendar.google.com/calendar/ical/en.usa%23holiday%40group.v.calendar.google.com/public/basic.ics" />
);

createRoot(rootElem).render(<App />);
