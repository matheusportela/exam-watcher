require 'json'
require 'mechanize'
require 'sinatra'

USERNAME = ''
PASSWORD = ''

LOGIN_URL = 'http://lappis.unb.br/moodle/login/index.php'
COURSE_URL = 'http://lappis.unb.br/moodle/course/view.php?id=2'
ASSIGNMENT_URL = 'http://lappis.unb.br/moodle/mod/assignment/view.php?id='
SUBMISSIONS_URL = 'http://lappis.unb.br/moodle/mod/assignment/submissions.php?perpage=100&id='

CLASS = 'JJ'

ASSIGNMENTS_IDS = {
    1 => 339,
    2 => 340,
    3 => 341,
    4 => 342,
    5 => 343
}

CLASS_IDS = {
    'GG' => 8,
    'II' => 9,
    'JJ' => 10,
}

class Watcher
    def initialize
        @agent = Mechanize.new
        @agent.user_agent_alias = 'Linux Firefox'
        @agent.follow_meta_refresh = true
        @agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        @agent
    end

    def do_login
        login_page = @agent.get(LOGIN_URL)
        login_form = login_page.form_with id: 'login'
        login_form.field_with(name: 'username').value = USERNAME
        login_form.field_with(name: 'password').value = PASSWORD
        login_form.submit
    end

    def go_to_course_page
        @agent.get(COURSE_URL)
    end

    def go_to_assignment_page(question_number, class_name: nil)
        url = "#{ASSIGNMENT_URL}#{ASSIGNMENTS_IDS[question_number]}"
        url += "&group=#{CLASS_IDS[class_name]}" unless class_name.nil?
        @agent.get(url)
    end

    def get_total_number_of_submissions(class_name)
        number_of_submissions = {}

        ASSIGNMENTS_IDS.keys.each do |question_number|
            number_of_submissions[question_number] = get_number_of_submissions(class_name, question_number)
        end

        number_of_submissions
    end

    def get_number_of_submissions(class_name, question_number)
        assignment_page = go_to_assignment_page(question_number, class_name: class_name)
        submissions_link = assignment_page.links.select { |l| l.text.include? 'submitted assignments' }.first
        return 0 if submissions_link.nil?
        submissions_link.text.split[1].to_i
    end

    def go_to_grades_page(question_number, page: nil, class_name: nil)
        url = "#{SUBMISSIONS_URL}#{ASSIGNMENTS_IDS[question_number]}"
        url += "&page=#{page}" unless page.nil?
        url += "&group=#{CLASS_IDS[class_name]}" unless class_name.nil?
        @agent.get(url)
    end

    def get_grades_for_question(class_name, question_number)
        grades = []

        grades_page = go_to_grades_page(question_number, class_name: class_name)
        grades_page.css('table#attempts tbody td.grade').each do |td|
            grades << td.text.split[0].to_i if not td.text.empty? and td.text != '-'
        end

        grades
    end

    def get_grades_statistics_for_question(class_name, question_number)
        grades = get_grades_for_question(class_name, question_number)
        grade_count = grades.group_by { |w| w }.map { |w, ws| [w, { value: ws.length, percentage: (100*ws.length/grades.count).to_i }] }.sort.to_h
        grade_labels = grade_count.map { |w, ws| w }.to_a
        grade_values = grade_count.map { |w, ws| ws[:value] }.to_a
        grade_percentages = grade_count.map { |w, ws| ws[:percentage] }.to_a

        {
            total_count: grades.count,
            grade_labels: grade_labels,
            grade_values: grade_values,
            grade_percentages: grade_percentages,
            grade_count: grade_count,
            max: grades.max,
            min: grades.min,
            average: grades.length == 0 ? nil : grades.inject(:+).to_f / grades.length
        }
    end

    def get_grades_statistics(class_name)
        grades_statistics = {}

        ASSIGNMENTS_IDS.keys.each do |question_number|
            grades_statistics[question_number] = get_grades_statistics_for_question(class_name, question_number)
        end

        first_grade_count = grades_statistics[ASSIGNMENTS_IDS.keys[0]][:total_count]
        ASSIGNMENTS_IDS.keys.each do |question_number|
            percentage = (100*grades_statistics[question_number][:total_count]/first_grade_count).to_i
            grades_statistics[question_number][:total_count_percentage] = percentage
        end

        grades_statistics
    end
end

watcher = Watcher.new
watcher.do_login
puts watcher.get_grades_statistics(CLASS)

before do
  content_type :json
  headers 'Access-Control-Allow-Origin' => '*'
end

after do
  response.body = JSON.dump(response.body)
end

get '/submissions' do
    watcher.get_total_number_of_submissions(CLASS)
end

get '/statistics' do
    watcher.get_grades_statistics(CLASS)
end
