const { parseICSTime, parseICS, groupEventsByDay } = require('../src/calendar');

describe('ICS parsing', () => {
  test('parseICSTime parses date-only strings', () => {
    const d = parseICSTime('20240102');
    expect(d.toISOString()).toBe('2024-01-02T00:00:00.000Z');
  });

  test('parseICSTime parses date-time strings', () => {
    const d = parseICSTime('20240102T123456Z');
    expect(d.toISOString()).toBe('2024-01-02T12:34:56.000Z');
  });

  test('parseICS extracts events and start dates', () => {
    const ics = 'BEGIN:VEVENT\nSUMMARY:Meet\nDTSTART:20240102T090000Z\nEND:VEVENT\nBEGIN:VEVENT\nSUMMARY:Party\nDTSTART:20240103\nEND:VEVENT';
    const events = parseICS(ics);
    expect(events.length).toBe(2);
    expect(events[0].summary).toBe('Meet');
    expect(events[0].startDate.toISOString()).toBe('2024-01-02T09:00:00.000Z');
    expect(events[1].startDate.toISOString()).toBe('2024-01-03T00:00:00.000Z');
  });

  test('groupEventsByDay groups by ISO date', () => {
    const events = [
      { startDate: new Date('2024-01-02T01:00:00Z'), summary: 'A' },
      { startDate: new Date('2024-01-02T10:00:00Z'), summary: 'B' },
      { startDate: new Date('2024-01-03T00:00:00Z'), summary: 'C' }
    ];
    const grouped = groupEventsByDay(events);
    expect(Object.keys(grouped)).toEqual(['2024-01-02', '2024-01-03']);
    expect(grouped['2024-01-02'].length).toBe(2);
    expect(grouped['2024-01-03'][0].summary).toBe('C');
  });
});
