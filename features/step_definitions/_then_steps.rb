require 'rubygems'
require 'timecop'

Then /^(.+) should be in the (\d+)(?:st|nd|rd|th) position of the sprint named (.+)$/ do |story_subject, position, sprint_name|
  position = position.to_i
  story = RbStory.find(:first, :conditions => ["subject=? and name=?", story_subject, sprint_name], :joins => :fixed_version)
  story.rank.should == position.to_i
end

Then /^I should see (\d+) sprint backlogs$/ do |count|
  sprint_backlogs = page.all(:css, "#sprint_backlogs_container .sprint")
  sprint_backlogs.length.should == count.to_i
end

Then /^I should see the burndown chart$/ do
  page.should have_css("#burndown_#{@sprint.id.to_s}")
end

Then /^I should see the Issues page$/ do
  page.should have_css("#query_form")
end

Then /^I should see the taskboard$/ do
  page.should have_css('#taskboard')
end

Then /^I should see the product backlog$/ do
  page.should have_css('#product_backlog_container')
end

Then /^I should see (\d+) stories in the product backlog$/ do |count|
  page.all(:css, "#product_backlog_container .backlog .story").length.should == count.to_i
end

Then /^show me the list of sprints$/ do
  header = [['id', 3], ['name', 18], ['sprint_start_date', 18], ['effective_date', 18], ['updated_on', 20]]
  data = RbSprint.open_sprints(@project).collect{|sprint| [sprint.id, sprint.name, sprint.start_date, sprint.effective_date, sprint.updated_on] }

  show_table("Sprints", header, data)
end

Then /^show me the list of shared sprints$/ do
  header = [['id', 3], ['name', 18], ['project id', 5], ['sprint_start_date', 18], ['effective_date', 18], ['updated_on', 20]]
  sprints = @project.shared_versions.scoped(:conditions => {:status => ['open', 'locked']}, :order => 'sprint_start_date ASC, effective_date ASC').collect{|v| v.becomes(RbSprint) } 
  data = sprints.collect{|sprint| [sprint.id, sprint.name, sprint.project_id, sprint.start_date, sprint.effective_date, sprint.updated_on] }

  show_table("Sprints", header, data)
end

Then /^show me the list of stories$/ do
  header = [['id', 5], ['position', 8], ['rank', 8], ['status', 12], ['subject', 30], ['sprint', 20]]
  data = RbStory.find(:all, :order => "position ASC").collect {|story|
    [story.id, story.position, story.rank, story.status.name, story.subject, story.fixed_version_id.nil? ? 'Product Backlog' : story.fixed_version.name]
  }

  show_table("Stories", header, data)
end

Then /^show me the sprint impediments$/ do
  puts "Impediments for #{@sprint.name}: #{@sprint.impediments.collect{|i| i.subject}.inspect}"
end

Then /^show me the projects$/ do
  show_projects
end

Then /^show me the response body$/ do
  puts page.driver.body
end

Then /^(.+) should be the higher item of (.+)$/ do |higher_subject, lower_subject|
  higher = RbStory.find(:all, :conditions => { :subject => higher_subject })
  higher.length.should == 1
  
  lower = RbStory.find(:all, :conditions => { :subject => lower_subject })
  lower.length.should == 1
  
  lower.first.higher_item.id.should == higher.first.id
end

Then /^the request should complete successfully$/ do
  verify_request_status(200)
end

Then /^the request should fail$/ do
  verify_request_status(401)
end

Then /^calendar feed download should (succeed|fail)$/ do |status|
  (status == 'succeed').should == page.body.include?('BEGIN:VCALENDAR')
end

Then /^the (\d+)(?:st|nd|rd|th) story in (.+) should be (.+)$/ do |position, backlog, subject|
  sprint = (backlog == 'the product backlog' ? nil : Version.find_by_name(backlog))
  story = RbStory.find_by_rank(position.to_i, RbStory.find_options(:project => @project, :sprint => sprint))

  story.should_not be_nil
  story.subject.should == subject
end

Then /^all positions should be unique$/ do
  RbStory.find_by_sql("select project_id, position, count(*) as dups from issues where not position is NULL group by project_id, position having count(*) > 1").length.should == 0
end

Then /^the (\d+)(?:st|nd|rd|th) task for (.+) should be (.+)$/ do |position, story_subject, task_subject|
  story = RbStory.find(:first, :conditions => ["subject=?", story_subject])
  story.should_not be_nil
  story.children.length.should be >= position.to_i
  story.children[position.to_i - 1].subject.should == task_subject
end

Then /^the server should return an update error$/ do
  page.driver.response.status.should == 400
end

Then /^the server should return (\d+) updated (.+)$/ do |count, object_type|
  page.all("##{object_type.pluralize} .#{object_type.singularize}").length.should == count.to_i
end

Then /^the sprint named (.+) should have (\d+) impediments? named (.+)$/ do |sprint_name, count, impediment_subject|
  sprint = RbSprint.find(:all, :conditions => { :name => sprint_name })
  sprint.length.should == 1
  sprint = sprint.first

  impediments = sprint.impediments
  impediments.size.should == count.to_i

  subjects = {}
  impediment_subject.split(/(?:\s+and\s+)|(?:\s*,\s*)/).each {|s|
    subjects[s] = 0
  }
  sprint.impediments.each{|i|
    subjects[i.subject].should_not be_nil
    subjects[i.subject] += 1 if subjects[i.subject]
  }
  subjects.values.select{|v| v == 0}.size.should == 0
end

Then /^the sprint should be updated accordingly$/ do
  sprint = RbSprint.find(@sprint_params['id'])
  
  sprint.attributes.each_key do |key|
    unless ['updated_on', 'created_on'].include?(key)
      case
        when sprint[key].nil?
          @sprint_params[key].should be_nil
        when key =~ /_date/
          sprint[key].strftime("%Y-%m-%d").should == @sprint_params[key]
        else
          sprint[key].should == @sprint_params[key]
      end
    end
  end
end

Then /^the status of the story should be set as (.+)$/ do |status|
  @story.reload
  @story.status.name.downcase.should == status
end

Then /^the story named (.+) should have (\d+) task named (.+)$/ do |story_subject, count, task_subject|
  stories = RbStory.find(:all, :conditions => { :subject => story_subject })
  stories.length.should == 1

  tasks = stories.first.descendants
  tasks.length.should == 1
  
  tasks.first.subject.should == task_subject
end

Then /^the story should be at the (top|bottom)$/ do |position|
  if position == 'top'
    story_position(@story).should == 1
  else
    story_position(@story).should == @story_ids.length
  end
end

Then /^the story should be at position (.+)$/ do |position|
  story_position(@story).should == position.to_i
end

Then /^the story should have a (.+) of (.+)$/ do |attribute, value|
  @story.reload
  if attribute=="tracker"
    attribute="tracker_id"
    value = Tracker.find(:first, :conditions => ["name=?", value]).id
  end
  @story[attribute].should == value
end

Then /^the wiki page (.+) should contain (.+)$/ do |title, content|
  title = Wiki.titleize(title)
  page = @project.wiki.find_page(title)
  page.should_not be_nil

  raise "\"#{content}\" not found on page \"#{title}\"" unless page.content.text.match(/#{content}/) 
end

Then /^(issue|task|story) (.+) should have (.+) set to (.+)$/ do |type, subject, attribute, value|
  issue = Issue.find_by_subject(subject)
  issue.send(attribute.intern).should == value.to_i
end

Then /^the sprint burn(down|up) should be:$/ do |direction, table|
  bd = nil
  Timecop.travel((@sprint.effective_date + 1).to_time) do
    bd = @sprint.burndown(direction)
  end

  days = @sprint.days(:all)
  days = [:first] + days

  table.hashes.each do |metrics|
    day = metrics.delete('day')
    day = (day == 'start' ? 0 : day.to_i)
    date = days[day]

    metrics.keys.sort{|a, b| a.to_s <=> b.to_s}.each do |k|
      expected = metrics[k]
      got = bd[k.intern][day]

      # If we get a nil, leave expected alone -- if expected is '' or nil, it'll match, otherwise it's a mismatch anyhow
      expected = got.to_s.match(/\./) ? expected.to_f : expected.to_i unless got.nil?

      "#{date}, #{k}: #{got}".should == "#{date}, #{k}: #{expected}"
    end
  end
end

Then /^show me the sprint burn(.*)$/ do |direction|
  bd = nil
  Timecop.travel((@sprint.effective_date + 1).to_time) do
    bd = @sprint.burndown(direction)
  end

  dates = @sprint.days(:all)
  dates = [:start] + dates

  header = ['day'] + bd.series(false).sort{|a, b| a.to_s <=> b.to_s}

  data = []
  days = bd.series(false).collect{|k| bd[k]}.collect{|s| s.size}.max
  0.upto(days - 1) do |day|
    data << ["#{dates[day]} (#{day})"] + header.reject{|h| h == 'day'}.collect{|k| bd[k][day]}
  end

  show_table("Burndown for #{@sprint.name} (#{@sprint.sprint_start_date} - #{@sprint.effective_date})", header, data)
end

Then /^show me the burndown for task (.+)$/ do |subject|
  task = RbTask.find_by_subject(subject)
  sprint = task.fixed_version.becomes(RbSprint)
  Timecop.travel((sprint.effective_date + 1).to_time) do
    show_table("Burndown for #{subject}, created on #{task.created_on}", ['date', 'hours'], (['start'] + sprint.days(:active)).zip(task.burndown))
  end
end

Then /^show me the (.+) journal for (.+)$/ do |property, subject|
  issue = Issue.find(:first, :conditions => ['subject = ?', subject.strip])
  raise "No issue with subject '#{subject}'" unless issue
  puts "\n"
  puts "#{issue.subject}(#{issue.id})##{property}, created: #{issue.created_on}"

  days = (issue.created_on.to_date .. Date.today).to_a
  previous = nil
  issue.history(property.intern, days).each_with_index {|value, i|
    next if i != 0 && value == previous
    previous = value
    puts "  #{days[i]}: #{value}"
  }
end

Then /^show me the story burndown for (.+)$/ do |story|
  Timecop.travel((@sprint.effective_date + 1).to_time) do
    story = RbStory.find(:first, :conditions => ['subject = ?', story])
    bd = story.burndown
    header = ['day'] + bd.keys.sort{|a, b| a.to_s <=> b.to_s}
    bd['day'] = ['start'] + @sprint.days(:active)
    data = bd.transpose.collect{|row| header.collect{|k| row[k]}}
    show_table("Burndown for story #{story.subject}", header.collect{|h| h.to_s}, data)
  end
end

Then /^task (.+) should have a total time spent of (\d+) hours$/ do |subject,value|
  issue = Issue.find_by_subject(subject)
  issue.spent_hours.should == value.to_f
end

Then /^sprint (.+) should contain (.+)$/ do |sprint_name, story_subject|
  story = RbStory.find(:first, :conditions => ["subject=? and name=?", story_subject, sprint_name], :joins => :fixed_version)
  story.should_not be_nil
end

Then /^the story named (.+) should have a task named (.+)$/ do |story_subject, task_subject|
  stories = RbStory.find(:all, :conditions => { :subject => story_subject })
  stories.length.should == 1

  tasks = RbTask.find(:all, :conditions => { :subject => task_subject, :parent_id => stories.first.id })
  tasks.length.should == 1
end

Then /^I should see (\d+) stories in the sprint backlog of (.+)$/ do |arg1, arg2|
  sprint = RbSprint.find(:first, :conditions => { :name => arg2.strip })
  sprint.should_not be_nil
  stories = page.all(:css, "#stories-for-#{sprint.id} .story")
  stories.length.should == arg1.to_i
end

Then /^I should (.*)be able to drag stories from project (.*) to the product backlog$/ do |neg, arg1|
  pending # express the regexp above with the code you wish you had
end

Then /^I should (.*)be able to drag stories from project (.*) to the sprint backlog of (.*)$/ do |neg, arg1, arg2|
  pending # express the regexp above with the code you wish you had
end

Then /^The menu of the sprint backlog of (.*) should (.*)allow to create a new Story in project (.*)$/ do |arg1, neg, arg3|
  sprint = RbSprint.find(:first, :conditions => {:name => arg1})
  project = get_project(arg3)
  links = page.all(:xpath, "//div[@id='sprint_#{sprint.id}']/..//a[contains(@class,'add_new_story')]")
  found = check_backlog_menu_new_story(links, project)
  found.should be !!(neg=='')
end

Then /^The menu of the product backlog should (.*)allow to create a new Story in project (.+)$/ do |neg, arg3|
  project = get_project(arg3)
  links = page.all(:css, "#product_backlog_container a.add_new_story")
  found = check_backlog_menu_new_story(links, project)
  found.should be !!(neg=='')
end

Then /^I should (.*)see the backlog of Sprint (.+)$/ do |neg, arg1|
  sprint = RbSprint.find(:first, :conditions => {:name => arg1})
  begin
    page.find(:css, "#sprint_#{sprint.id}")
    found = true
  rescue
    found = false
  end
  found.should be !!(neg=='')
end

Then /^I should (.*)be able to drag story (.+) from sprint (.+) before the story (.+) in the product backlog$/ do |neg, story, sprint, target|
  story = RbStory.find(:first, :conditions => {
    :fixed_version_id => RbSprint.find(:first, :conditions => {:name => sprint }).id,
    :subject => story})
  story_id = story.id
  old_v_id = story.fixed_version_id
  element = page.find(:css, "#story_#{story_id}")

  target_id = RbStory.find(:first, :conditions => {:fixed_version_id => nil, :subject => target}).id
  target = page.find(:css, "#story_#{target_id}")

  element.drag_to(page.find(:css, "#stories-for-product-backlog")) #extra step to trick out jquery sortable which needs movement???
  element.drag_to(target)
  sleep 1 #FIXME (pa sharing) wait for ajax to happen. capybara does not see the change since the dom node is still on the page

  story.reload
  story.fixed_version_id.should be neg=='' ? nil : old_v_id
end

Then /^show me a screenshot at (.+)$/ do |arg1|
  page.driver.render(arg1)
end

Then /^dump the database to (.+)$/ do |arg1|
  system("pg_dump redmine_test > #{arg1}")
end

