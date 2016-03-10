require 'dnsruby'
module Intrigue
class DnsLookupTxtTask < BaseTask

  def metadata
    {
      :name => "dns_lookup_txt",
      :pretty_name => "DNS TXT Lookup",
      :authors => ["jcran"],
      :description => "DNS TXT Lookup",
      :references => [
        "http://webmasters.stackexchange.com/questions/27910/txt-vs-spf-record-for-google-servers-spf-record-either-or-both"
      ],
      :allowed_types => ["DnsRecord"],
      :example_entities => [{"type" => "DnsRecord", "attributes" => {"name" => "intrigue.io"}}],
      :allowed_options => [
        {:name => "resolver", :type => "String", :regex => "ip_address", :default => "8.8.8.8" }
      ],
      :created_types => ["DnsRecord", "IpAddress", "Info", "NetBlock" ]
    }
  end

  def run
    super

    domain_name = _get_entity_attribute "name"
    opt_resolver = _get_option "resolver"

    @task_result.logger.log "Running TXT lookup on #{domain_name}"

    begin
      res = Dnsruby::Resolver.new(
      :nameserver => opt_resolver,
      :search => [],
      :recurse => true,
      :query_timeout => 5)

      res_answer = res.query(domain_name, Dnsruby::Types.TXT)

      # If we got a success to the query.
      if res_answer
        @task_result.logger.log_good "TXT lookup succeeded on #{domain_name}:"
        @task_result.logger.log_good "Answer:\n=======\n#{res_answer.to_s}======"


        # TODO - Parse for netbocks and hostnames

        #     res_answer.downcase.split("ipv4").
        #     create_entity NetBlock, :range

        # Create a finding for each
        unless res_answer.answer.count == 0
          res_answer.answer.each do |answer|
            answer.rdata.first.split(" ").each do |record|

              if record =~ /^include:.*/
                _create_entity "DnsRecord", {"name" => record.split(":").last}
              elsif record =~ /^ip4:.*/
                s = record.split(":").last
                if s.include? "/"
                  _create_entity "NetBlock", {"name" => s }
                else
                  _create_entity "IpAddress", {"name" => s }
                end
              elsif record =~ /^google-site-verification.*/
                _create_entity "Info", {"name" => "DNS Verification Code", "type" =>"Google", "content" => record.split(":").last}
              elsif record =~ /^yandex-verification.*/
                _create_entity "Info", {"name" => "DNS Verification Code", "type" =>"Yandex", "content" => record.split(":").last}
              end
            end

            # Log an info record with full detail
            _create_entity "Info", { :name => "TXT Record", :content => answer.to_s , :details => res_answer.to_s }

          end
        end

      end

    rescue Dnsruby::Refused
      @task_result.logger.log "Lookup against #{domain_name} refused."

    rescue Dnsruby::ResolvError
      @task_result.logger.log "Unable to resolve #{domain_name}"

    rescue Dnsruby::ResolvTimeout
      @task_result.logger.log "Timed out while querying #{domain_name}."

    rescue Exception => e
      @task_result.logger.log "Unknown exception: #{e}"
    end

    @task_result.logger.log "done"
  end


end
end
