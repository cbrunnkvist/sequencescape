module SampleManifest::SampleTubeBehaviour
  module ClassMethods
    def create_for_sample_tube!(attributes, *args, &block)
      create!(attributes.merge(:asset_type => '1dtube'), *args, &block).tap do |manifest|
        manifest.generate
      end
    end
  end

  class Core
    def initialize(manifest)
      @manifest = manifest
    end

    delegate :generate_1dtubes, :to => :@manifest
    alias_method(:generate, :generate_1dtubes)

    delegate :samples, :to => :@manifest

    def io_samples
      samples.map do |sample|
        {
          :sample    => sample,
          :container => {
            :barcode => sample.primary_tube.sanger_human_barcode
          }
        }
      end
    end

    def print_labels(&block)
      printables = self.samples.map do |sample|
        sample_tube = sample.assets.first
        BarcodeLabel.new(
          :number => sample_tube.sanger_human_barcode,
          :study  => sample.sanger_sample_id,
          :prefix => sample_tube.prefix, :suffix => ""
        )
      end
      yield(printables, 'NT')
    end

    def updated_by!(user, samples)
      # Does nothing at the moment
    end

    def details(&block)
      samples.each do |sample|
        yield({
          :barcode   => sample.assets.first.sanger_human_barcode,
          :sample_id => sample.sanger_sample_id
        })
      end
    end
  end

  # There is no reason for this to need a rapid version as it should be reasonably
  # efficient in the first place.
  RapidCore = Core

  def self.included(base)
    base.class_eval do
      extend ClassMethods
    end
  end

  def generate_1dtubes
    sanger_ids = generate_sanger_ids(self.count)
    study_abbreviation = self.study.abbreviation

    tubes, samples_data = [], []
    (0...self.count).each do |_|
      sample_tube = SampleTube.create!
      sanger_sample_id = SangerSampleId.generate_sanger_sample_id!(study_abbreviation, sanger_ids.shift)

      tubes << sample_tube
      samples_data << [sample_tube.barcode,sanger_sample_id,sample_tube.prefix]
    end

    self.barcodes = tubes.map(&:sanger_human_barcode)

    sample_tube_sample_creation(samples_data,self.study.id)
    delayed_generate_asset_requests(tubes, self.study)
    save!
  end

  def sample_tube_sample_creation(samples_data,study_id)
    study_samples_data = []
    samples_data.each do |barcode,sanger_sample_id,prefix|
      sample      = create_sample(sanger_sample_id)
      sample_tube = SampleTube.find_by_barcode(barcode)
      sample_tube.sample = sample
      sample_tube.save!
      study_samples_data << [study_id, sample.id]
    end
    delayed_generate_study_samples(study_samples_data)
  end
  private :sample_tube_sample_creation
end
