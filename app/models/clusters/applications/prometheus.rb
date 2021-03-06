module Clusters
  module Applications
    class Prometheus < ActiveRecord::Base
      VERSION = "2.0.0".freeze

      self.table_name = 'clusters_applications_prometheus'

      include ::Clusters::Concerns::ApplicationCore
      include ::Clusters::Concerns::ApplicationStatus

      default_value_for :version, VERSION

      state_machine :status do
        after_transition any => [:installed] do |application|
          application.cluster.projects.each do |project|
            project.find_or_initialize_service('prometheus').update(active: true)
          end
        end
      end

      def chart
        'stable/prometheus'
      end

      def service_name
        'prometheus-prometheus-server'
      end

      def service_port
        80
      end

      def chart_values_file
        "#{Rails.root}/vendor/#{name}/values.yaml"
      end

      def install_command
        Gitlab::Kubernetes::Helm::InstallCommand.new(name, chart: chart, chart_values_file: chart_values_file)
      end

      def proxy_client
        return unless kube_client

        proxy_url = kube_client.proxy_url('service', service_name, service_port, Gitlab::Kubernetes::Helm::NAMESPACE)

        # ensures headers containing auth data are appended to original k8s client options
        options = kube_client.rest_client.options.merge(headers: kube_client.headers)
        RestClient::Resource.new(proxy_url, options)
      end

      private

      def kube_client
        cluster&.kubeclient
      end
    end
  end
end
