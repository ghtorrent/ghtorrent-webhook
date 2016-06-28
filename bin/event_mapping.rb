#!/usr/bin/env ruby

require 'uri'
require_relative 'json_builder'

module GHTorrentWebhook
  
  # Function that takes event from webhooks and transforms it into a JSON object structured like events from the Events API
  #
  # Works for push, create, delete, fork, gollum, issues, issue comment, watch, pull request, pull request review comments,
  # and member events.
  #
  # This is meant to be used by ght-webhook before passing data to MongoDB so that the DB can be normalized
  def convert_json(event, event_name)
    builder = JSON_Builder.new #generate_header(event)
    event_type = ""
  
    case event_name
    when "push"
      event_type = "PushEvent"
      builder = convert_push_event(event, builder)
    when "create"
      event_type = "CreateEvent"
      builder = convert_create_event(event, builder)
    when "delete"
      event_type = "DeleteEvent"
      builder = convert_delete_event(event, builder)
    when "fork"
      event_type = "ForkEvent"
      builder = convert_fork_event(event, builder)
    when "gollum"
      event_type = "GollumEvent"
      builder = convert_gollum_event(event, builder)
    when "issues"
      event_type = "IssuesEvent"
      builder = convert_issue_event(event, builder)
    when "issue_comment"
      event_type = "IssueCommentEvent"
      builder = convert_issue_comment_event(event, builder)
    when "watch"
      event_type = "WatchEvent"
      builder = convert_watch_event(event, builder)
    when "pull_request"
      event_type = "PullRequestEvent"
      builder = convert_pull_request_event(event, builder)
    when "pull_request_review_comment"
      event_type="PullRequestReviewCommentEvent"
      builder = convert_pull_request_review_comment_event(event, builder)
    when "commit_comment"
      event_type="CommitCommentEvent"
      builder = convert_commit_comment_event(event, builder)
    when "member"
      event_type = "MemberEvent"
      builder = convert_member_event(event, builder)
    else
      return nil, "unsupported"
    end
    
    builder = generate_footer(event, builder, event_type)
    return builder.return_object(), event_type
  end

  #properties found in all events (things outside of the payload)
  def generate_footer(event, builder, type)
    builder.add_property("id",   request.env['HTTP_X_GITHUB_DELIVERY'])
    builder.add_property("type", type)
    builder_actor = JSON_Builder.new           #generate actor
    builder_actor.add_property("id"            ,event["sender"]["id"])
    builder_actor.add_property("login"         ,event["sender"]["login"])
    builder_actor.add_property("gravatar_id"   ,event["sender"]["gravatar_id"])
    builder_actor.add_property("url"           ,event["sender"]["url"])
    builder_actor.add_property("avatar_url"    ,event["sender"]["avatar_url"])
    builder.add_property_object("actor"        ,builder_actor)
    builder_repo = JSON_Builder.new            #generate repo
    builder_repo.add_property("id"             ,event["repository"]["id"])
    builder_repo.add_property("name"           ,event["repository"]["name"])
    builder_repo.add_property("url"            ,event["repository"]["url"])
    builder.add_property_object("repo"         ,builder_repo)
        
    #determine if the repo is public or private
    if event["repository"]["private"] == true
      builder.add_property("public", false)
    else
      builder.add_property("public", true)
    end
    
    builder.add_property("created_at", event["repository"]["created_at"].to_s)
    if event["organization"] != nil #org may not be in the returned data (may be a user)
      builder_org = JSON_Builder.new
      builder_org.add_property("id"          ,event["organization"]["id"])
      builder_org.add_property("url"         ,event["organization"]["url"])
      builder_org.add_property("login"       ,event["organization"]["login"])
      builder_org.add_property("avatar_url"  ,event["organization"]["avatar_url"])
      builder_org.add_property("gravatar_id" ,"") #no gravatar_id equivalent is given through webhooks
      builder.add_property_object("org"      ,builder_org)
    end

    return builder
  end

  #MemberEvent
  def convert_member_event(event, builder)
    builder_payload = JSON_Builder.new
    builder_payload.add_property("action", event["action"])
    builder_payload.add_JSON_object_recursive("member", event["member"])
    builder.add_property_object("payload", builder_payload)

    return builder
  end

  #CommitCommentEvent
  def convert_commit_comment_event(event, builder)
    builder_payload_comment = JSON_Builder.new
    builder_payload_comment.add_JSON_object_recursive("comment", event["comment"])
    builder.add_property_object("payload", builder_payload_comment)

    return builder
  end

  #PullRequestReviewComment
  def convert_pull_request_review_comment_event(event, builder)
    builder_payload = JSON_Builder.new
    builder_payload.add_property("action", event["action"])
    builder_payload.add_JSON_object_recursive("pull_request" ,event["pull_request"])
    builder_payload.add_JSON_object_recursive("comment"      ,event["comment"])
    builder.add_property_object("payload", builder_payload)

    return builder
  end

  #PullRequestEvent
  def convert_pull_request_event(event, builder)
    builder_payload = JSON_Builder.new
    builder_payload.add_JSON_object_recursive("pull_request", event["pull_request"])
    builder_payload.add_property("action", event["action"])
    builder_payload.add_property("number", event["number"])
    builder.add_property_object("payload", builder_payload)

    return builder
  end

  #WatchEvent
  def convert_watch_event(event, builder)
    builder_payload = JSON_Builder.new
    builder_payload.add_property("action", event["action"])
    builder.add_property_object("payload", builder_payload)

    return builder
  end

  #IssueCommentEvent
  def convert_issue_comment_event(event, builder)
    builder_payload              = JSON_Builder.new
    builder_payload_issue        = JSON_Builder.new.get_JSON_object(event["issue"])
    builder_payload_issue_user   = JSON_Builder.new.get_JSON_object(event["issue"]["user"])
    builder_payload_comment      = JSON_Builder.new.get_JSON_object(event["comment"])
    builder_payload_comment_user = JSON_Builder.new.get_JSON_object(event["comment"]["user"])
    builder_payload.add_property("action", event["action"])
    builder_payload_issue.add_property("repository_url", event["repository"]["url"])
    builder_payload_issue.add_property_object("user", builder_payload_issue_user)
    builder_payload.add_property_object("issue", builder_payload_issue)
    builder_payload_comment.add_property_object("user", builder_payload_comment_user)
    builder_payload.add_property_object("comment", builder_payload_comment)
    builder.add_property_object("payload", builder_payload)

    return builder
  end 

  #IssueEvent
  def convert_issue_event(event, builder)
    builder_payload            = JSON_Builder.new
    builder_payload_issue      = JSON_Builder.new.get_JSON_object(event["issue"])
    builder_payload_issue_user = JSON_Builder.new.get_JSON_object(event["issue"]["user"])
    builder_payload.add_property("action", event["action"])
    builder_payload_issue.add_property("repository_url", event["repository"]["url"])
    builder_payload_issue.add_property_object("user", builder_payload_issue_user)
    builder_payload.add_property_object("issue", builder_payload_issue)
    builder.add_property_object("payload", builder_payload)

    return builder
  end

  #GollumEvent
  def convert_gollum_event(event, builder)
    builder_payload = JSON_Builder.new  
    builder_payload.add_array("pages"     ,event["pages"])
    builder.add_property_object("payload" ,builder_payload)

    return builder
  end

  #ForkEvent
  def convert_fork_event(event, builder)
    builder_payload = JSON_Builder.new
    forkee          = JSON_Builder.new.get_JSON_object(event["forkee"])
    forkee.add_property_object("owner", forkee.get_JSON_object(event["forkee"]["owner"]))
    builder_payload.add_property_object("forkee", forkee)
    builder.add_property_object("payload", builder_payload);

    return builder
  end

  #DeleteEvent
  def convert_delete_event(event, builder)
    builder_payload = JSON_Builder.new
    builder_payload.add_property("ref"         ,event["ref"])
    builder_payload.add_property("ref_type"    ,event["ref_type"])
    builder_payload.add_property("pusher_type" ,event["pusher_type"])
    builder.add_property_object("payload"      ,builder_payload)

    return builder
  end

  #CreateEvent
  def convert_create_event(event, builder)
    builder_payload = JSON_Builder.new
    builder_payload.add_property("ref"           ,event["ref"])
    builder_payload.add_property("ref_type"      ,event["ref_type"])
    builder_payload.add_property("master_branch" ,event["master_branch"])
    builder_payload.add_property("description"   ,event["description"])
    builder_payload.add_property("pusher_type"   ,event["pusher_type"])
    builder.add_property_object("payload"        ,builder_payload)

    return builder
  end

  #PushEvent
  def convert_push_event(event, builder)
    #generate all commits
    commit_builders, num_commits, num_distinct_commits = generate_commits(event)
    builder_payload = JSON_Builder.new           #build payload
    builder_payload.add_property("size"          ,num_commits)
    builder_payload.add_property("distinct_size" ,num_distinct_commits)
    builder_payload.add_property("ref"           ,event["ref"])
    builder_payload.add_property("before"        ,event["before"])
    builder_payload.add_property("head"          ,event["head_commit"] == nil ? "" : event["head_commit"]["id"])

    builder_payload.add_array("commits", commit_builders)
    builder.add_property_object("payload", builder_payload)

    return builder
  end

  #Function to format and add all commits
  def generate_commits(event)
    num_commits = event["commits"].length
    num_distinct_commits = 0
    commit_builders = Array.new
  
    if event["head_commit"] != nil
      commit_builders, num_distinct_commits = add_commit(event, event["head_commit"], commit_builders, num_distinct_commits)
      num_commits += 1
    end
    
    #generate all commits in payload
    for commit in event["commits"]
      commit_builders, num_distinct_commits = add_commit(event, commit, commit_builders, num_distinct_commits)
    end
    
    return commit_builders, num_commits, num_distinct_commits
  end

  #Function to format and add one event
  def add_commit(event, commit, commit_builders, num_distinct_commits)
    sha_hash = URI(commit["url"]).path.split('/').last
    if commit["distinct"] == true
      num_distinct_commits += 1
    end
  
    builder_commit        = JSON_Builder.new
    builder_commit_author = JSON_Builder.new
    builder_commit.add_property("sha", sha_hash)
    builder_commit_author.add_property("email"  ,commit["author"]["email"])
    builder_commit_author.add_property("name"   ,commit["author"]["name"])
    builder_commit.add_property_object("author" ,builder_commit_author)
    builder_commit.add_property("message"  ,commit["message"])
    builder_commit.add_property("distinct" ,commit["distinct"])
    builder_commit.add_property("url"      ,commit["url"])
    
    commit_builders.push(builder_commit)
    
    return commit_builders, num_distinct_commits
  end
end
