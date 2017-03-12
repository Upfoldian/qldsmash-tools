module QLDSmashTools

	require 'json'
	require 'nokogiri'
	require 'open-uri'
	require 'net/https'

	@@longToShortHash = {"New South Wales" => "NSW", "Queensland" => "QLD", "Australian Capital Territory" => "ACT", "Northern Territory" => "NT", "Western Australia" => "WA",
					"Victoria" => "VIC", "South Australia" => "SA", "Tasmania" => "TAS", "New Zealand" => "NZ"}
	@@shortToLongHash = {"NSW" => "New South Wales", "QLD" => "Queensland", "ACT" => "Australian Capital Territory", "NT" => "Northern Territory", "WA" => "Western Australia",
					"VIC" => "Victoria", "SA" => "South Australia", "TAS" => "Tasmania", "NZ" => "New Zealand"}

	attr_accessor :results 

	def self.update()
		eloPage = nil
		print "Connecting to QLDSmash..."
		begin
			eloPage = Nokogiri::HTML(open("https://qldsmash.com/Elo/SSBU", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
		rescue
			"could not establish connection to QLDSmash"
			return 
		end

		puts "Connected.\nScrape process started..."

		players = {:players => []}

		eloPage.xpath("//tr[@class='rating-row']").each do |player|
			begin

				newPlayer = {:name => "", :region => "", :elo => 0, :regionalRank => "", :movement => 0}

				playerInfo = player.xpath("td")
				newPlayer[:regionalRank] = playerInfo[1].xpath("span[@class='elo-local']").text.strip
				#just magic, nothing to see here
				movement = playerInfo[2].text.strip.split("\n")
				newPlayer[:movement] = movement.size == 1 ? 0 : movement[-1].to_i
				#no more magic
				newPlayer[:elo] = playerInfo[2].xpath("text()").to_s.strip.to_i
				newPlayer[:region] = playerInfo[3].xpath("img/@alt").text.strip
				newPlayer[:name] = playerInfo[4].xpath("a/text()").to_s.strip

				players[:players].push newPlayer

			rescue
				puts "something went wrong with scraping, yell at Baker"
			end
		end

		puts "Done! Data saved to qldsmash-data.json"
		File.open("qldsmash-data.json", 'w') { |file| file.write(JSON.pretty_generate(players))}

		@@results = JSON.parse(File.read('qldsmash-data.json'))

	end

	def self.eloMovements(state)
		#Returns a sorted list (highest -> lowest) of elo movements for the given state
		#Notes:
		# 	- Expects short state name e.g. "NSW", "SA"
		# 	- Assumes self.update() has been run at least once
		# 	- returns as a list of hashes [ {name: => playerName, :movement => eloMovement, :total => totalElo}] sorted by :movement

		players = @@results["players"].select{|x| x["region"] == @@shortToLongHash[state]}
		remap = players.map {|player| {:name => player["name"], :movement => player["movement"], :total => player["elo"]}}
		eloMovements = remap.sort_by {|player| player[:movement]}.reverse

		return eloMovements

	end

	def self.eloTotals(state)
		#Returns a sorted list (highest -> lowest) of elo totals for the given state
		#Notes:
		# 	- Expects short state name e.g. "NSW", "SA"
		# 	- Assumes self.update() has been run at least once
		# 	- returns as a list of hashes [ {name: => playerName, :movement => eloMovement, :total => totalElo}] sorted by :total


		players = @@results["players"].select{|x| x["region"] == @@shortToLongHash[state]}
		remap = players.map {|player| {:name => player["name"], :movement => player["movement"], :total => player["elo"]}}
		eloTotals = remap.sort_by {|player| player[:total]}.reverse

		return eloTotals

	end
	
	# def self.getPlayerData(names)
	# 	# Returns an array of hash entries that correspond to the index of names param
	# 	names.each do |name|

	# 	end

	# end

	def self.getPlayerHistory(name, state)

		history = {:matches => []}
		puts "Connecting to #{name}'s (#{state}) QLDSmash profile page..."
		begin 
			resultsPage = Nokogiri::HTML(open("https://qldsmash.com/Players/#{state}?p=#{name}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
		rescue
			puts "could not open player profile. Check that the playername/state are correct, but it might also be a connection issue"
			return history
		end

		matches = []
		puts "Connection established. Scraping player data."
		matchData = resultsPage.xpath("//div[@class='panel match-history  panel-success']").each do |match|
			#only win data, changes opponent locations from "col-xs-5" to just "col-xs-5 text-right"

			curMatch = {:event => "", :date => Date.new, :opponent => "", :opponentElo => 0, :win? => false, :data => ""}

			if match.xpath("@data-filter-game").to_s.strip == "SSBU"
				curMatch[:win?] = true
				curMatch[:opponentElo] = match.xpath("@data-filter-opponent").to_s.strip.to_i
				curMatch[:event] = match.xpath("div[@class='panel-heading']/a/text()").to_s.strip
				curMatch[:data] = match.xpath("div[@class='panel-body']/div[@class='row']/div[@class='col-xs-2 text-center']").text.strip
				curMatch[:opponent] = match.xpath("div[@class='panel-body']/div[@class='row']/div[@class='col-xs-5 text-right']/div/a/text()").to_s.strip
				date = match.xpath("div[@class='panel-footer']/div[@class='row']/div[@class='col-xs-6 text-right']").text.strip
				curMatch[:date] = Date.strptime(date, '%d/%m/%Y')

				matches.push curMatch
			end
		end

		matchData = resultsPage.xpath("//div[@class='panel match-history  panel-danger']").each do |match|
			#only loss data, changes opponent locations from "col-xs-5 text-right" to just "col-xs-5"
			curMatch = {:event => "", :date => Date.new, :opponent => "", :opponentElo => 0, :win? => false, :data => ""}

			if match.xpath("@data-filter-game").to_s.strip == "SSBU"
				curMatch[:win?] = false
				curMatch[:opponentElo] = match.xpath("@data-filter-opponent").to_s.strip.to_i
				curMatch[:event] = match.xpath("div[@class='panel-heading']/a/text()").to_s.strip
				curMatch[:data] = match.xpath("div[@class='panel-body']/div[@class='row']/div[@class='col-xs-2 text-center']").text.strip
				curMatch[:opponent] = match.xpath("div[@class='panel-body']/div[@class='row']/div[@class='col-xs-5']/div/a/text()").to_s.strip
				date = match.xpath("div[@class='panel-footer']/div[@class='row']/div[@class='col-xs-6 text-right']").text.strip
				curMatch[:date] = Date.strptime(date, '%d/%m/%Y')

				matches.push curMatch
			end
		end

		matches = matches.sort_by{|match| match[:date]}
		matches = matches.map do |match|
			match[:date] = match[:date].to_s
			match
		end

		history[:matches] = matches

		return history

	end


	def self.headToHead(player1, player2)
		#Returns a hash of head-to-head data for player1 and player2 in the following format:
		# 	{:score => "", :setCount => "", :winRate => "", :lastBeatDate => "", :lastBeatEvent => "", :lastLostDate => "", :lastLostEvent => "", :eloDiff => ""}
		# Notes:
		# 	- Only works for NSW players
		# 	- Does not handle same named players
		# 	- can look nicer
		# 	- is case insensitive (ty qldsmash)
		h2hPage = nil
		begin
			h2hPage = Nokogiri::HTML(open("https://qldsmash.com/Players/Compare/SSBU/NSW/#{player1}/NSW/#{player2}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
		rescue
			#puts "trouble fetching player data, are you sure the player names are correct?"
			return {}
		end

		info = {:score => "", :setCount => "", :winRate => "", :lastBeatDate => "", :lastBeatEvent => "", :lastLostDate => "", :lastLostEvent => "", :eloDiff => ""}


		info[:score] = h2hPage.xpath("//div[@class='text-center score']").text.strip

		liElements = h2hPage.xpath("//div[@class='alert alert-info']/ul/li")
		info[:winRate] 			= liElements[0].xpath("strong")[0].text.strip
		info[:setCount] 		= liElements[0].xpath("strong")[1].text.strip.gsub(" games", "")
		#stuff changes if they haven't beaten them (pretty lazy workaround)
		begin
			info[:lastBeatDate]		= Date.parse(liElements[1].xpath("strong")[1].text.strip).to_s
			info[:lastBeatEvent] 	= liElements[1].text.strip.split(" at ")[-1][0..-2]
		rescue
			info[:lastBeatDate] 	= "never"
			info[:lastBeatEvent] 	= "never"
		end
		#stuff changes if they haven't lost to them (pretty lazy workaround)
		begin
			info[:lastLostDate]		= Date.parse(liElements[2].xpath("strong")[1].text.strip).to_s
			info[:lastLostEvent] 	= liElements[2].text.strip.split(" at ")[-1][0..-2]
		rescue
			info[:lastLostDate]		= "never"
			info[:lastLostEvent] 	= "never"
		end

		eloDiffArr = liElements[3].xpath("strong")[0].text.strip.split(" ")
		info[:eloDiff]			= eloDiffArr[1] == "more" ? "+" + eloDiffArr[0].to_s : (eloDiffArr[0].to_i * -1).to_s

		return info

	end
end

QLDSmashTools.update