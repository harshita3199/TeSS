require 'test_helper'

class AutocompleteSuggestionTest < ActiveSupport::TestCase
  setup do
    AutocompleteSuggestion.add('keywords', 'apple', 'APPLICATION', 'Aardvark', 'banana', 'BAnaNA')
  end

  test 'query' do
    autocompleter = AutocompleteSuggestion.where(field: 'keywords')
    assert_equal ['Aardvark', 'apple', 'APPLICATION'], autocompleter.query('a')

    assert_equal ['apple', 'APPLICATION'], autocompleter.query('ap')
    assert_equal ['apple', 'APPLICATION'], autocompleter.query('Ap')
    assert_equal ['apple', 'APPLICATION'], autocompleter.query('aP')
    assert_equal ['apple', 'APPLICATION'], autocompleter.query('AP')

    assert_equal ['apple'], autocompleter.query('apple')
    assert_equal ['apple'], autocompleter.query('APPLE')

    assert_equal [], autocompleter.query('plums')

    assert_equal ['banana', 'BAnaNA'], autocompleter.query('ban')
    assert_equal ['banana', 'BAnaNA'], autocompleter.query('Ban')
    assert_equal ['banana', 'BAnaNA'], autocompleter.query('bAn')

    assert_equal ['Aardvark'], autocompleter.query('a', 1)
    assert_equal ['Aardvark', 'apple'], autocompleter.query('a', 2)
  end

  test 'add' do
    assert_difference('AutocompleteSuggestion.count', 2) do
      AutocompleteSuggestion.add('keywords', 'apple', 'banana', 'grape', 'pineapple')
    end

    assert_no_difference('AutocompleteSuggestion.count', 0) do
      AutocompleteSuggestion.add('keywords', 'apple', 'banana', 'grape', 'pineapple')
    end

    assert_difference('AutocompleteSuggestion.count', 1) do
      AutocompleteSuggestion.add('keywords', 'AppLE', 'banana', 'grape', 'pineapple')
    end

    assert_difference('AutocompleteSuggestion.count', 4) do
      AutocompleteSuggestion.add('new_field', 'apple', 'banana', 'grapefruit', 'pineapple')
    end
  end

  test 'refresh' do
    suggestion = AutocompleteSuggestion.where(field: 'keywords', value: 'apple').first
    assert suggestion
    id = suggestion.id

    assert_difference('AutocompleteSuggestion.count', -3) do
      AutocompleteSuggestion.refresh('keywords', 'apple', 'starfruit')
    end

    assert_equal id, AutocompleteSuggestion.where(field: 'keywords', value: 'apple').first.id
    assert_equal ['apple', 'starfruit'], AutocompleteSuggestion.where(field: 'keywords').query('')
  end
end
