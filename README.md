# GHTorrent webhook

Minimal script to act as a webhook for GitHub projects. It accepts `POST`
requests on port 4567, reads the JSON event, checks if it is already saved
in MongoDB and posts the event on the queue for further processing.

It was written to help realtime monitoring of private repos, using exactly
the same mechanism as GHTorrent does.

### Installing and Running

Install `bunder`,  checkout the repository and do `bundle install`

```bash
(sudo) gem install bundler
git clone git@github.com:ghtorrent/ghtorrent-webhook.git
(sudo) bundle install
```

Then, copy the file `config.yaml.tmpl` to `config.yaml` and edit it to
point to your installation of RabbitMQ and MongoDB.

Then you can run the hook as follows:

```bash
CONFIG=config.yaml bundle exec bin/ght-webhook
```

the config file is either read from the environment or as the first
command line argument.