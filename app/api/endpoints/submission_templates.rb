class Endpoints::SubmissionTemplates < Core::Endpoint::Base
  model do

  end

  instance do
    factory(:to => 'submissions', :json => 'submissions') do |request, _|
      ActiveRecord::Base.transaction do
        request.create!(::Io::Submission.map_parameters_to_attributes(request.json).merge(:user => request.user))
      end
    end
  end
end
