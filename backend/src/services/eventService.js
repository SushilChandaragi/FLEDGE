const Event = require('../models/Event');
const { HttpError } = require('../utils/HttpError');

async function getActiveEvent(eventId) {
  const event = await Event.findOne({ eventId, active: true });
  if (!event) throw new HttpError(404, 'event_not_found', 'This event is not active.');
  return event;
}

function toPublic(event) {
  return {
    eventId: event.eventId,
    eventName: event.eventName,
    description: event.description,
    date: event.date,
    time: event.time,
    venue: event.venue,
    registrationFormUrl: event.registrationFormUrl,
  };
}

module.exports = { getActiveEvent, toPublic };
