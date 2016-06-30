#!/usr/bin/env ruby

require 'uri'

module GHTorrentWebhook
  
  # Function that takes event from webhooks and transforms it into a JSON object structured like events from the Events API
  #
  # Works for push, create, delete, fork, gollum, issues, issue comment, watch, pull request, pull request review comments,
  # and member events.
  #
  # This is meant to be used by ght-webhook before passing data to MongoDB so that the DB can be normalized
  def convert_json(event, event_name)
    event_type = ""
    json = Hash.new
    
    case event_name
    when "push"
      event_type = "PushEvent"
      json = convert_push_event(event, json)
    when "create"
      event_type = "CreateEvent"
      json = convert_create_event(event, json)
    when "delete"
      event_type = "DeleteEvent"
      json = convert_delete_event(event, json)
    when "fork"
      event_type = "ForkEvent"
      json = convert_fork_event(event, json)
    when "gollum"
      event_type = "GollumEvent"
      json = convert_gollum_event(event, json)
    when "issues"
      event_type = "IssuesEvent"
      json = convert_issue_event(event, json)
    when "issue_comment"
      event_type = "IssueCommentEvent"
      json = convert_issue_comment_event(event, json)
    when "watch"
      event_type = "WatchEvent"
      json = convert_watch_event(event, json)
    when "pull_request"
      event_type = "PullRequestEvent"
      json = convert_pull_request_event(event, json)
    when "pull_request_review_comment"
      event_type="PullRequestReviewCommentEvent"
      json = convert_pull_request_review_comment_event(event, json)
    when "commit_comment"
      event_type="CommitCommentEvent"
      json = convert_commit_comment_event(event, json)
    when "member"
      event_type = "MemberEvent"
      json = convert_member_event(event, json)
    else
      return nil, "unsupported"
    end
    
    json = generate_footer(event, json, event_type)
    return json, event_type
  end

  #properties found in all events (things outside of the payload)
  def generate_footer(event, json, type)
    json['id']    = request.env['HTTP_X_GITHUB_DELIVERY']
    json['type']  = type
    json['actor'] = {
       'id'          => event['sender']['id'],
       'login'       => event['sender']['login'],
       'gravatar_id' => event['sender']['gravatar_id'],
       'url'         => event['sender']['url'],
       'avatar_url'  => event['sender']['avatar_url']
    }
    json['repo'] = {
      'id'   => event['repository']['id'],
      'name' => event['repository']['name'],
      'url'  => event['repository']['url']
    }
        
    #determine if the repo is public or private
    if event["repository"]["private"] == true
      json['public'] = false
    else
      json['public'] = true
    end
    
    json['created_at'] = event['repository']['created_at']
    if event["organization"] != nil #org may not be in the returned data (may be a user)
      json['org'] = {
        'id'          => event['organization']['id'],
        'url'         => event['organization']['url'],
        'login'       => event['organization']['login'],
        'avatar_url'  => event['organization']['avatar_url'],
        'gravatar_id' => ''
      }
    end

    return json
  end

  #MemberEvent
  def convert_member_event(event, json)
    json['payload'] = {
      'action' => event['action'],
      'member' => event['member']
    }

    return json
  end

  #CommitCommentEvent
  def convert_commit_comment_event(event, json)
    json['payload'] = {
      'comment' => event['comment']
    }

    return json
  end

  #PullRequestReviewComment
  def convert_pull_request_review_comment_event(event, json)
    json['payload'] = {
      'action'       => event['action'],
      'pull_request' => event['pull_request'],
      'comment'      => event['comment']
    }

    return json
  end

  #PullRequestEvent
  def convert_pull_request_event(event, json)
    json['payload'] = {
      'pull_request' => event['pull_request'],
      'action'       => event['action'],
      'number'       => event['number']
    }

    return json
  end

  #WatchEvent
  def convert_watch_event(event, json)
    json['payload'] = {
      'action' => event['action']
    }

    return json
  end

  #IssueCommentEvent
  def convert_issue_comment_event(event, json)
    json['payload'] = {
      'action'  => event['action'],
      'issue'   => event['issue'],
      'comment' => event['comment']
    }
    json['payload']['issue']['repository_url'] = event['repository']['url']
    json['payload']['issue'].delete 'assignees'

    return json
  end 

  #IssueEvent
  def convert_issue_event(event, json)
    json['payload'] = {
      'action' => event['action'],
      'issue'  => event['issue'] 
    }
    json['payload']['issue']['repository_url'] = event['repository']['url']
    json['payload']['issue'].delete 'assignees'

    return json
  end

  #GollumEvent
  def convert_gollum_event(event, json)
    json['payload'] = {
      'pages' => event['pages']
    }

    return json
  end

  #ForkEvent
  def convert_fork_event(event, json)
    json['payload'] = {
      'forkee' => event['forkee']
    }

    return json
  end

  #DeleteEvent
  def convert_delete_event(event, json)
    json['payload'] = {
      'ref'         => event['ref'],
      'ref_type'    => event['ref_type'],
      'pusher_type' => event['pusher_type']
    }

    return json
  end

  #CreateEvent
  def convert_create_event(event, json)
    json['payload'] = {
      'ref'           => event['ref'],
      'ref_type'      => event['ref_type'],
      'master_branch' => event['master_branch'],
      'description'   => event['description'],
      'pusher_type'   => event['pusher_type']
    }

    return json
  end

  #PushEvent
  def convert_push_event(event, json)
    #generate all commits
    commit_json, num_commits, num_distinct_commits = generate_commits(event)
    json['payload'] = {
      'size'          => num_commits,
      'distinct_size' => num_distinct_commits,
      'ref'           => event['ref'],
      'before'        => event['before'],
      'head'          => event['head_commit'] == nil ? '' : event['head_commit']['id'],
      'commits'       => commit_json
    }

    return json
  end

  #Function to format and add all commits
  def generate_commits(event)
    num_commits = event['commits'].length
    num_distinct_commits = 0
    commit_json_arr = Array.new
  
    if event['head_commit'] != nil
      commit_json_arr, num_distinct_commits = add_commit(event, event['head_commit'], commit_json_arr, num_distinct_commits)
      num_commits += 1
    end
    
    #generate all commits in payload
    for commit in event['commits']
      commit_json_arr, num_distinct_commits = add_commit(event, commit, commit_json_arr, num_distinct_commits)
    end
    
    return commit_json_arr, num_commits, num_distinct_commits
  end

  #Function to format and add one event
  def add_commit(event, commit, commit_json_arr, num_distinct_commits)
    sha_hash = URI(commit['url']).path.split('/').last
    if commit['distinct'] == true
      num_distinct_commits += 1
    end
    json = {
      'sha'      => sha_hash,
      'message'  => commit['message'],
      'distinct' => commit['distinct'],
      'url'      => commit['url'],
      'author'   => {
        'email'  => commit['author']['email'],
        'name'   => commit['author']['name']
      }
    }
    
    commit_json_arr.push(json)
    
    return commit_json_arr, num_distinct_commits
  end
end
