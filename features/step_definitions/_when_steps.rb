require 'pp'

When /^I (try to )?create the impediment( on project )?(.*)$/ do |attempt, on, project|
  params = @impediment_params.dup
  params['project_id'] = Project.find(project) if project != ''
  page.driver.post(
                      url_for(:controller => :rb_impediments, :action => :create),
                      @impediment_params
                  )

  page.driver.response.status.should == 200 if attempt == ''
end

When /^I (try to )?create the story$/ do |attempt|
  page.driver.post(
                      url_for(:controller => :rb_stories, :action => :create),
                      @story_params
                  )
  page.driver.response.status.should == 200 if attempt == ''
end

When /^I (try to )?create the task$/ do |attempt|
  initial_estimate = @task_params.delete('initial_estimate')
  page.driver.post(
                      url_for(:controller => :rb_tasks, :action => :create),
                      @task_params
                  )
  page.driver.response.status.should == 200 if attempt == ''
end

When /^I (try to )?create the sprint$/ do |attempt|
  page.driver.post(
                      url_for(:controller => :rb_sprints, :action => :create),
                      @sprint_params
                  )
  page.driver.response.status.should == 200 if attempt == ''
end

When /^I (try to )?move the story named (.+) below (.+)$/ do |attempt, story_subject, prev_subject|
  story = RbStory.find(:first, :conditions => ["subject=?", story_subject])
  prev  = RbStory.find(:first, :conditions => ["subject=?", prev_subject])
  
  attributes = story.attributes
  attributes[:prev]             = prev.id
  attributes[:fixed_version_id] = prev.fixed_version_id

  page.driver.post(
                      url_for(:controller => 'rb_stories', :action => "update", :id => story.id),
                      attributes.merge({ "_method" => "put" })
                  )
  page.driver.response.status.should == 200 if attempt == ''
end

When /^I (try to )?move the story named (.+) (up|down) to the (\d+)(?:st|nd|rd|th) position of the sprint named (.+)$/ do |attempt, story_subject, direction, position, sprint_name|
  position = position.to_i
  story = RbStory.find_by_subject(story_subject)
  sprint = RbSprint.find_by_name(sprint_name)
  story.fixed_version = sprint
  
  attributes = story.attributes
  attributes[:prev] = story_before(position, sprint.project, sprint).to_s

  # TODO: why do we need 'direction'?

  page.driver.post(
                      url_for(:controller => 'rb_stories', :action => "update", :id => story.id),
                      attributes.merge({ "_method" => "put" })
                  )
  verify_request_status(200)
end

When /^I (try to )?move the (\d+)(?:st|nd|rd|th) story to the (\d+|last)(?:st|nd|rd|th)? position$/ do |attempt, old_pos, new_pos|
  @story_ids = page.all(:css, "#product_backlog_container .stories .story .id .v").collect{|s| s.text}
#  @story_ids = page.all(:css, "#product_backlog_container .stories .story .id .v")

  story_id = @story_ids.delete_at(old_pos.to_i-1)
  story_id.should_not == nil

  new_pos = new_pos.to_i unless new_pos == 'last'
  case new_pos
    when 'last'
      nxt = ''
    else
      nxt = @story_ids[new_pos-1]
  end

  page.driver.post( 
                      url_for(:controller => :rb_stories,
                              :action => :update,
                              :id => story_id,
                              :only_path => true),
                      {:next => nxt, :project_id => @project.id, "_method" => "put"}
                  )
  verify_request_status(200)

  @story = RbStory.find(story_id.to_i)
end

When /^I (try to )?request the server_variables resource$/ do |attempt|
  visit url_for(:controller => :rb_server_variables, :action => :project, :project_id => @project.id, :format => 'js', :only_path => true)
  verify_request_status(200) # sharing
end

When /^I (try to )?update the impediment$/ do |attempt|
  page.driver.post( 
                      url_for(:controller => :rb_impediments, :action => :update, :id => @impediment_params['id']),
                      @impediment_params
                  )
  page.driver.response.status.should == 200 if attempt == ''
end

When /^I (try to )?update the sprint$/ do |attempt|
  page.driver.post(
                      url_for(:controller => 'rb_sprints', :action => "update", :sprint_id => @sprint_params['id']),
                      @sprint_params.merge({ "_method" => "put" })
                  )
  page.driver.response.status.should == 200 if attempt == ''
end

When /^I (try to )?update the story$/ do |attempt|
  page.driver.post(
                      url_for(:controller => :rb_stories, :action => :update, :id => @story_params[:id]),
                      @story_params #.merge({ "_method" => "put" })
                  )
  page.driver.response.status.should == 200 if attempt == ''
  @story.reload
end

When /^I (try to )?update the task$/ do |attempt|
  page.driver.post(
                      url_for(:controller => :rb_tasks, :action => :update, :id => @task_params[:id]),
                      @task_params.merge({ "_method" => "put" })
                  )
  page.driver.response.status.should == 200 if attempt == ''
end

Given /^I visit the scrum statistics page$/ do
  visit url_for(:controller => 'rb_all_projects', :action => 'statistics', :only_path => true)
end

When /^I try to download the calendar feed$/ do
  visit url_for({ :key => @api_key, :controller => 'rb_calendars', :action => 'ical', :project_id => @project, :format => 'xml', :only_path => true})
end

When /^I view the master backlog$/ do
  visit url_for(:controller => :projects, :action => :show, :id => @project, :only_path => true)
  click_link("Backlogs")
end

When /^I view the stories of (.+) in the issues tab/ do |sprint_name|
  sprint = RbSprint.find(:first, :conditions => ["name=?", sprint_name])
  visit url_for(:controller => :rb_queries, :action => :show, :project_id => sprint.project_id, :sprint_id => sprint.id, :only_path => true)
end

When /^I view the stories in the issues tab/ do
  visit url_for(:controller => :rb_queries, :action => :show, :project_id=> @project.id, :only_path => true)
end

When /^I view the sprint notes$/ do
  visit url_for(:controller => 'rb_wikis', :action => 'show', :sprint_id => @sprint.id, :only_path => true)
end

When /^I edit the sprint notes$/ do
  visit url_for(:controller => 'rb_wikis', :action => 'edit', :sprint_id => @sprint.id, :only_path => true)
end

When /^the browser fetches (.+) updated since (\d+) (\w+) (.+)$/ do |object_type, how_many, period, direction|
  date = eval("#{ how_many }.#{ period }.#{ direction=='from now' ? 'from_now' : 'ago' }")
  date = date.strftime("%B %d, %Y %H:%M:%S") + '.' + (date.to_f % 1 + 0.001).to_s.split('.')[1]
  visit url_for(:controller => 'rb_updated_items', :action => :show, :project_id => @project.id, :only => object_type, :since => date, :only_path => true)
end

When /^I click (create|copy|save)$/ do |command|
  page.find(:xpath, '//input[@name="commit"]').click
end

When /^I drag story (.+) to the sprint backlog of (.+?)( before the story (.+))?$/ do |story, sprint, before, beforearg|
  story = RbStory.find(:first, :conditions => { :subject => story.strip})
  story.should_not be_nil
  element = page.find(:css, "#story_#{story.id}")

  sprint = RbSprint.find(:first, :conditions => {:name => sprint.strip })
  sprint.should_not be_nil
  target = page.find(:css, "#stories-for-#{sprint.id}")
  element.drag_to(target)
  if before and beforearg
    before = RbStory.find(:first, :conditions => {:subject => beforearg.strip})
    before.should_not be_nil
    element.drag_to(page.find(:css, "#story_#{before.id}"))
  end
  sleep 1 #FIXME (pa sharing) wait for ajax to happen. capybara does not see the change since the dom node is still on the page
  story.reload
end
