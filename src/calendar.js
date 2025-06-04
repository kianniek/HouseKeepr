function parseICSTime(s) {
  if (!s) return null;
  const m = s.match(/(\d{4})(\d{2})(\d{2})(T(\d{2})(\d{2})(\d{2})Z?)?/);
  if (!m) return null;
  const [, y, mo, d, , h = '0', mi = '0', sec = '0'] = m;
  return new Date(Date.UTC(+y, +mo - 1, +d, +h, +mi, +sec));
}

function parseICS(text) {
  const events = [];
  const blocks = text.split('BEGIN:VEVENT').slice(1);
  for (const block of blocks) {
    const body = block.split('END:VEVENT')[0];
    const summary = (body.match(/SUMMARY:(.+)/) || [])[1];
    const start = (body.match(/DTSTART(?:;[^:]+)?:([^\n\r]+)/) || [])[1];
    const end = (body.match(/DTEND(?:;[^:]+)?:([^\n\r]+)/) || [])[1];
    if (summary && start) {
      events.push({
        summary: summary.trim(),
        start: start.trim(),
        end: end ? end.trim() : '',
        startDate: parseICSTime(start.trim())
      });
    }
  }
  return events;
}

function groupEventsByDay(events) {
  const map = {};
  events.forEach(ev => {
    if (!ev.startDate) return;
    const key = ev.startDate.toISOString().slice(0, 10);
    if (!map[key]) map[key] = [];
    map[key].push(ev);
  });
  return map;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { parseICSTime, parseICS, groupEventsByDay };
}

if (typeof window !== 'undefined') {
  window.parseICSTime = parseICSTime;
  window.parseICS = parseICS;
  window.groupEventsByDay = groupEventsByDay;
}
