--
-- Inofficial MoneyMoney extension for Provinzial
--
--
-- Copyright (c) 2023 Alex Merkel
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

WebBanking {
    version = 0.1,
    url = "https://kundenportal.provinzial.com",
    services = {"Provinzial"},
    description = "Provinzial"
}

--------------------------------------------------------------------------------

function SupportsBank (protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == "Provinzial"
end

--------------------------------------------------------------------------------

local connection = nil
local response = nil
local connection = Connection()

--------------------------------------------------------------------------------

function InitializeSession (protocol, bankCode, username, reserved, password)
    connection.language = "de-de"

    print("Version " .. version)
    response = HTML(connection:get("https://kundenportal.provinzial.com/anmeldung/login"))

    response:xpath("//input[@name='username']"):attr("value", username)
    response:xpath("//input[@name='password']"):attr("value", password)
    response = HTML(connection:request(response:xpath("//*[@id='anmeldenButtonId']"):click()))

    if string.find(response:xpath("//*[@class='serverMsg']"):text(),"Bitte versuchen Sie es noch einmal") then
        return LoginFailed
    end
end

--------------------------------------------------------------------------------

function ListAccounts (knownAccounts)
    local accounts = {}

    response = HTML(connection:request(response:xpath("//a[@title='zu meinen Verträgen']"):click()))
    response:xpath("//*/div[contains(concat(' ',normalize-space(@class),' '),' vertrag ')]"):each(
        function(index, element)
            if (element:xpath("//p[@class='h4']"):text() == "Fondsgebundene ­Renten­versicherung") then
                local versicherungsnummer = tonumber(element:xpath("//p[@class='versicherungsnummer']"):text())
                local versicherungsname = element:xpath("//p[@id='KP_vertrag_zusatzInfo_value']"):text()
                table.insert(
                    accounts,
                    {
                        name = versicherungsname,
                        accountNumber = versicherungsnummer,
                        currency = "EUR",
                        portfolio = true,
                        type = AccountTypePortfolio
                    }
                )
            end
        end
    )

    return accounts
end

--------------------------------------------------------------------------------

function RefreshAccount (account, since)
    local securities = {}

    url = "https://kundenportal.provinzial.com/vertrag/vertraege/leben/LN" .. string.format("%020d", account.accountNumber)
    print(url)
    response = HTML(connection:get(url))
    response:xpath("//dl[dt/a[text()='Fondsdaten']]/dd/div/ul/li/div/div"):each(
        function(index, element)
            -- Convert date
            s=element:xpath(".//div[@id='KP_VertragPersonenDatenLebenAO_fondKursdatum_value']"):text()
            print(s)
            p="(%d+).(%d+).(%d+)"
            day,month,year=s:match(p)
            offset=os.time()-os.time(os.date("!*t"))
            timestamp = os.time({day=day,month=month,year=year,hour=12,min=0,sec=0,isdst=false})+offset
            -- Get numbers
            quantity = string.gsub(element:xpath(".//div[@id='KP_VertragPersonenDatenLebenAO_fondAnteile_value']"):text(), ',', '.')
            print(quantity)
            price = string.gsub(element:xpath(".//div[@id='KP_VertragPersonenDatenLebenAO_fondKurs_value']"):text(), ',', '.')
            print(price)
            amount = string.gsub(element:xpath(".//div[@id='KP_VertragPersonenDatenLebenAO_fondWert_value']"):text(), ',', '.')
            print(amount)
            -- Add to table
            table.insert(
                securities,
                {
                    isin = element:xpath(".//div[@id='KP_VertragPersonenDatenLebenAO_fondIsin_value']"):text(),
                    name = element:xpath(".//div[@id='KP_VertragPersonenDatenLebenAO_fondName_value']"):text(),
                    quantity = quantity,
                    price = price,
                    amount = amount,
                    tradeTimestamp = timestamp
                }
            )
        end
    )

    return {securities = securities}
end

--------------------------------------------------------------------------------


function EndSession ()
    connection:post("https://kundenportal.provinzial.com/anmeldung/logout", "")
end

-- SIGNATURE: MC0CFA3ZYgD9uEkPNd3F4NpV9BUdVGZ/AhUAjvJTdpXltpKMdZB9cQhY5N1pZKI=
