FactoryBot.define do
  factory :pull_request do
    number { 123 }
    release { build(:release) }

    started_time { Time.new(2021, 12, 2) }
    opened_time { Time.new(2021, 12, 31) }
    merged_time { Time.new(2022, 1, 1) }
    number_of_commits { 2 }
    total_line_changes { 24 }
    number_of_reviews { 1 }
    number_of_comments { 2 }

    initialize_with { new(number, release: release) }
  end
end
