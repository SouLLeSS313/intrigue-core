require 'dnsruby'

module Intrigue
class DnsTransferZoneTask < BaseTask

  def metadata
    {
      :name => "dns_transfer_zone",
      :pretty_name => "DNS Zone Transfer",
      :authors => ["jcran"],
      :description => "DNS Zone Transfer",
      :allowed_types => ["DnsRecord"],
      :example_entities => [
        {"type" => "DnsRecord", "attributes" => {"name" => "intrigue.io"}}
      ],
      :allowed_options => [ ],
      :created_types => ["DnsRecord","Info","IpAddress"]
    }
  end

  def run
    super

    domain_name = _get_entity_attribute "name"

    # Get the nameservers
    authoritative_nameservers = []
    Resolv::DNS.open do |dns|
      resources = dns.getresources(domain_name, Resolv::DNS::Resource::IN::NS)
      resources.each do |r|
        dns.each_resource(r.name, Resolv::DNS::Resource::IN::A){ |x| authoritative_nameservers << x.address.to_s }
      end
    end

    # For each authoritive nameserver
    authoritative_nameservers.each do |nameserver|
      begin

        @task_result.logger.log "Attempting Zone Transfer on #{domain_name} against nameserver #{nameserver}"

        # Do the actual zone transfer
        zt = Dnsruby::ZoneTransfer.new
        zt.transfer_type = Dnsruby::Types.AXFR
        zt.server = nameserver
        zone = zt.transfer(domain_name)

        _create_entity "Info", {
          "name" => "Zone Transfer",
          "content" => "#{nameserver} -> #{domain_name}",
          "details" => zone
        }

        # Create host records for each item in the zone
        zone.each do |z|
          if z.type == "SOA" || z.type == "TXT"
            _create_entity "DnsRecord", { "name" => z.name.to_s, "type" => z.type.to_s, "content" => "#{z.to_s}" }
          else
            _create_entity "DnsRecord", { "name" => z.name.to_s, "type" => z.type.to_s, "content" => "#{z.to_s}" }
            # Check to see what type this record's content is.
            # MX records are of form: [10, #<Dnsruby::Name: vv-cephei.ac-grenoble.fr.>
            z.rdata.kind_of?(Dnsruby::Name) ? record = z.rdata.to_s : z.rdata.last.to_s
            # Check to see if it's an ip address or a dns record
            record.is_ip_address? ? entity_type = "IpAddress" : entity_type = "DnsRecord"
            _create_entity entity_type, { "name" => "#{record}", "type" => "#{z.type.to_s}", "content" => "#{record}" }
          end
        end

      rescue Dnsruby::Refused => e
        @task_result.logger.log "Zone Transfer against #{domain_name} refused: #{e}"
      rescue Dnsruby::ResolvError => e
        @task_result.logger.log "Unable to resolve #{domain_name} while querying #{nameserver}: #{e}"
      rescue Dnsruby::ResolvTimeout =>  e
        @task_result.logger.log "Timed out while querying #{nameserver} for #{domain_name}: #{e}"
      rescue Errno::EHOSTUNREACH => e
        @task_result.logger.log_error "Unable to connect: (#{e})"
      rescue Errno::ECONNREFUSED => e
        @task_result.logger.log_error "Unable to connect: (#{e})"
      rescue Errno::ECONNRESET => e
        @task_result.logger.log_error "Unable to connect: (#{e})"
      rescue Errno::ETIMEDOUT => e
        @task_result.logger.log_error "Unable to connect: (#{e})"
      end # end begin
    end # end .each
  end # end run



end
end
