# GHTorrent webhook

Minimal script to act as a webhook for GitHub projects. It accepts `POST`
requests on port 3000, reads the JSON event, checks if it is already saved
in MongoDB and posts the event on the queue for further processing.

It was written to help realtime monitoring of private repos, using exactly
the same mechanism as GHTorrent does.
