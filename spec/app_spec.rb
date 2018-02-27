# frozen_string_literal: true

require_relative 'spec_helper'

describe 'root' do
  before { get '/' }

  it { expect(last_response).to be_ok }
end

describe 'config' do
  before { get '/config.xml' }

  it { expect(last_response).to be_ok }
  it { expect(last_response.content_type).to include('application/xml') }
  it 'has a launch_url' do
    config = Nokogiri::XML(last_response.body)
    expect(config.at_xpath('//blti:launch_url')).to be_present
  end
end

describe 'credentials' do
  it 'renders a generate credentials buttons' do
    get '/credentials/new'
    expect(last_response).to have_css('.credentials-generate-btn')
  end

  it 'generates new credentials' do
    expect { post '/credentials' }.to change { AuthCredential.count }.by(1)
    credential = Nokogiri::HTML(last_response.body).css('.credential-value').first
    expect(credential).to be_present
    expect(credential.text).to eq AuthCredential.last.key
  end
end

describe 'LTI authentication' do
  it 'requires a valid key/secret pair' do
    post '/lti/course-navigation'
    expect(last_response.status).to eq 401
    expect(last_response.body).to include('No key/pair credentials for')
  end

  it 'requires an valid oauth signature' do
    lti_request '/lti/course-navigation', signature: 'wrong-signature'
    expect(last_response.status).to eq 401
    expect(last_response.body).to include('Invalid Signature')
  end

  it 'expires the timestamp in 5 minutes' do
    lti_request '/lti/course-navigation', timestamp: (Time.current - 5.minutes).to_i
    expect(last_response.status).to eq 401
    expect(last_response.body).to include('Timestamp expired')
  end

  it 'set session user when request is valid' do
    lti_request '/lti/course-navigation'
    expect(last_response).to be_ok
    expect(session['user_id']).to eq 'user-id'
  end
end

describe 'course-navigation' do
  it 'authenticates oauth LTI requests' do
    lti_request '/lti/course-navigation'
    expect(last_response).to be_ok
  end

  it 'render file-browser component when is authorized on google' do
    allow_any_instance_of(GoogleAuth).to receive(:credentials).and_return(OpenStruct.new)
    lti_request '/lti/course-navigation'
    expect(last_response).to have_css('.file-browser')
    component = Nokogiri::HTML(last_response.body).css('.file-browser').first
    expect(component.attr('data-browser-type')).to eq 'navigation'
  end
end

describe 'editor-selection' do
  it 'authenticates oauth LTI requests' do
    lti_request '/lti/editor-selection'
    expect(last_response).to be_ok
  end

  it 'render file-browser component when is authorized on google' do
    allow_any_instance_of(GoogleAuth).to receive(:credentials).and_return(OpenStruct.new)
    lti_request '/lti/editor-selection'
    expect(last_response).to have_css('.file-browser')
    component = Nokogiri::HTML(last_response.body).css('.file-browser').first
    expect(component.attr('data-browser-type')).to eq 'selection'
  end
end