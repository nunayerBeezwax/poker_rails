class Question < ActiveRecord::Base
require 'open-uri'
@@tagger = EngTagger.new

	def question_type
		question_words = %w{which what whose who whom where when how}
		question_words.each {|w| return w if self.text.downcase[w] != nil}
	end

	def find_the_answer
		@choices = self.choice_array
		q = question_type
		search = operative_word
		if q == "which"
			search_by_choices
		else
			wiki_page = Nokogiri::HTML(open("http://en.wikipedia.org/w/api.php?action=query&prop=revisions&titles=#{search}&redirects&rvprop=content&format=json&rvparse=1"))
			File.open("tmp/picAIune.html", "w") do |f|
				f.puts wiki_page
			end
			word_count = {}
			words = File.read("tmp/picAIune.html").split(" ")
			string = words.join(" ").downcase
			sanitized_string = string.gsub(/\/[,()'":<>=.]/,'')
			answer = {}
			@choices.each { |w| answer[w] = string.scan(/#{Regexp.quote(w)}/).size if w != '' }
			if !answer.values.any?{ |v| v > 0 }
				self.update(answer: "I don't know")
			else
				answer.each{|k, v| "#{k} === #{v}"}
				self.update(answer: answer.sort_by{|k, v| v}.reverse.first[0].titleize)
			end
		end
	end

	def call_wikipedia_json(search)
		uri = URI("http://en.wikipedia.org/w/api.php?action=query&prop=revisions&titles=#{search}&redirects&rvprop=content&format=json&rvparse=1")
		response = Net::HTTP.get_response(uri)
		json = JSON.parse(response.body)
		File.open("tmp/picAIune.json", "w") do |f|
			f.puts json
		end
		binding.pry
	end	

	def call_wikipedia_api(search)
		data = Nokogiri::HTML(open("http://en.wikipedia.org/w/api.php?action=query&prop=revisions&titles=#{search}&redirects&rvprop=content&format=json&rvparse=1"))
		File.open("tmp/picAIune.html", "w") do |f|
			f.puts data
		end
	end

	def call_duck_api(search)
		ddg = DuckDuckGo.new
		zci = ddg.zeroclickinfo(search)
	end

	def call_wolfram_api(search)
		data = Nokogiri::HTML(open("http://api.wolframalpha.com/v2/query?appid=#{ENV["WOLFRAM_API_KEY"]}&input=#{search}&format=image,plaintext"))
		File.open("tmp/picAIune.html", "w") do |f|
			f.puts data
		end
		good_stuff = data.css('plaintext')
	end

	def search_by_choices
		@choices.each do |search|
			call_wikipedia_api(search)
			word_count = {}
			words = File.read("tmp/picAIune.html").split(" ")
			string = words.join(" ").downcase
			sanitized_string = string.gsub(/\/[,()'":<>=.]/,'')
			answer = {}
			nouns.keys[0..-2].each { |w| answer[w] = string.scan(/#{Regexp.quote(w)}/).size if w != '' }
			if !answer.values.any?{ |v| v > 0 }
				self.update(answer: "I don't know")
			else
				answer.each{|k, v| "#{k} === #{v}"}
				self.update(answer: answer.sort_by{|k, v| v}.reverse.first[0].titleize)
			end
		end
	end

	def tag
		@@tagger.add_tags(self.text)
	end

	def proper_nouns
		@@tagger.get_proper_nouns(self.tag)
	end

	def nouns
		@@tagger.get_nouns(self.tag)
	end

	def choice_array
		choices = []
		choices << self.choice1.downcase unless self.choice1.nil?
		choices << self.choice2.downcase unless self.choice2.nil?
		choices << self.choice3.downcase unless self.choice3.nil?
		choices << self.choice4.downcase unless self.choice4.nil?
		choices
	end

	def operative_word
		if proper_nouns.length > 0
			proper_nouns.keys.join("%20")
		else
			nouns.keys.last
		end
	end

	def dictionary_lookup(word)
		wiki_page = Nokogiri::HTML(open("http://en.wiktionary.org/w/index.php?action=raw&prop=revisions&title=#{word}&redirects&rvprop=content&format=json&rvparse=1"))
		File.open("tmp/picAIune.html", "w") do |f|
			f.puts wiki_page
		end
		word_count = Hash.new(0)
		words = File.read("tmp/picAIune.html").split(" ")
		string = words.join(" ").downcase
		sanitized_string = string.gsub(/\/[,()'":<>=.]/,'')
		sanitized_string.split(" ").each { |word| word_count[word] += 1 }
	end
	##following code copy/pasted from EngTagger for picAIune purposes

	 def strip_tags(tagged, downcase = false)
    return nil unless valid_text(@tagged)
    text = @tagged.gsub(/<[^>]+>/m, "")
    text = text.gsub(/\s+/m, " ")
    text = text.gsub(/\A\s*/, "")
    text = text.gsub(/\s*\z/, "")
    if downcase
      return text.downcase
    else
      return text
    end
  end
end