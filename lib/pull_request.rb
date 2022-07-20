class PullRequest
  attr_accessor :number, :started_time, :opened_time, :merged_time,
    :number_of_commits, :total_line_changes, :number_of_reviews, :number_of_comments

  def initialize(number)
    @number = number
  end

  def ==(other)
    number == other.number &&
      started_time == other.started_time &&
      opened_time == other.opened_time &&
      merged_time == other.merged_time &&
      number_of_commits == other.number_of_commits &&
      total_line_changes == other.total_line_changes &&
      number_of_reviews == other.number_of_reviews &&
      number_of_comments == other.number_of_comments
  end
  alias_method :eql?, :==
end
