# frozen_string_literal: true
RSpec.shared_examples 'a Valkyrie::StorageAdapter' do
  before do
    raise 'storage_adapter must be set with `let(:storage_adapter)`' unless
      defined? storage_adapter
    raise 'file must be set with `let(:file)`' unless
      defined? file
    class Valkyrie::Specs::CustomResource < Valkyrie::Resource
    end
  end
  after do
    Valkyrie::Specs.send(:remove_const, :CustomResource)
  end
  subject { storage_adapter }
  it { is_expected.to respond_to(:handles?).with_keywords(:id) }
  it { is_expected.to respond_to(:find_by).with_keywords(:id) }
  it { is_expected.to respond_to(:delete).with_keywords(:id) }
  it { is_expected.to respond_to(:upload).with_keywords(:file, :resource, :original_filename) }
  it { is_expected.to respond_to(:supports?) }

  it "can upload a file which is just an IO" do
    io_file = Tempfile.new('temp_io')
    io_file.write "Stuff"
    io_file.rewind
    sha1 = Digest::SHA1.file(io_file).to_s

    resource = Valkyrie::Specs::CustomResource.new(id: SecureRandom.uuid)

    expect(uploaded_file = storage_adapter.upload(file: io_file, original_filename: 'foo.jpg', resource: resource, fake_upload_argument: true)).to be_kind_of Valkyrie::StorageAdapter::File

    expect(uploaded_file.valid?(digests: { sha1: sha1 })).to be true
  end

  it "doesn't leave a file handle open on upload/find_by" do
    # No file handle left open from upload.
    resource = Valkyrie::Specs::CustomResource.new(id: "testdiscovery")
    pre_open_files = open_files
    uploaded_file = storage_adapter.upload(file: file, original_filename: 'foo.jpg', resource: resource, fake_upload_argument: true)
    file.close
    expect(pre_open_files.size).to eq open_files.size

    # No file handle left open from find_by
    pre_open_files = open_files
    the_file = storage_adapter.find_by(id: uploaded_file.id)
    expect(the_file).to be_kind_of Valkyrie::StorageAdapter::File
    expect(pre_open_files.size).to eq open_files.size
  end

  def open_files
    `lsof +D .`.split("\n").map { |r| r.split("\t").last }
  end

  it "can upload, validate, re-fetch, and delete a file" do
    resource = Valkyrie::Specs::CustomResource.new(id: "test")
    sha1 = Digest::SHA1.file(file).to_s
    size = file.size
    expect(uploaded_file = storage_adapter.upload(file: file, original_filename: 'foo.jpg', resource: resource, fake_upload_argument: true)).to be_kind_of Valkyrie::StorageAdapter::File

    expect(uploaded_file).to respond_to(:checksum).with_keywords(:digests)
    expect(uploaded_file).to respond_to(:valid?).with_keywords(:size, :digests)
    expect(uploaded_file.checksum(digests: [Digest::SHA1.new])).to eq([sha1])
    expect(uploaded_file.valid?(digests: { sha1: sha1 })).to be true
    expect(uploaded_file.valid?(size: size, digests: { sha1: sha1 })).to be true
    expect(uploaded_file.valid?(size: (size + 1), digests: { sha1: sha1 })).to be false
    expect(uploaded_file.valid?(size: size, digests: { sha1: 'bogus' })).to be false

    expect(storage_adapter.handles?(id: uploaded_file.id)).to eq true
    file = storage_adapter.find_by(id: uploaded_file.id)
    expect(file.id).to eq uploaded_file.id
    expect(file).to respond_to(:stream).with(0).arguments
    expect(file).to respond_to(:read).with(0).arguments
    expect(file).to respond_to(:rewind).with(0).arguments
    expect(file.stream).to respond_to(:read)
    new_file = Tempfile.new
    expect { IO.copy_stream(file, new_file) }.not_to raise_error

    storage_adapter.delete(id: uploaded_file.id)
    expect { storage_adapter.find_by(id: uploaded_file.id) }.to raise_error Valkyrie::StorageAdapter::FileNotFound
    expect { storage_adapter.find_by(id: Valkyrie::ID.new("noexist")) }.to raise_error Valkyrie::StorageAdapter::FileNotFound
  end

  it "can upload and find new versions" do
    pending "Versioning not supported" unless storage_adapter.supports?(:versions)
    size = file.size
    resource = Valkyrie::Specs::CustomResource.new(id: "test")
    uploaded_file = storage_adapter.upload(file: file, original_filename: 'foo.jpg', resource: resource, fake_upload_argument: true)

    f = Tempfile.new
    f.puts "Test File"
    f.rewind

    new_version = storage_adapter.upload_version(file: f, original_filename: 'foo_final.jpg', previous_version_id: uploaded_file.id)
    expect(uploaded_file.id).to eq new_version.id

    versions = storage_adapter.find_versions(id: new_version.id)
    expect(versions.length).to eq 2
    expect(versions.first.id).to eq new_version.id
    expect(versions.first.size).not_to eq size
    # TODO
    # 1. How do I delete a version
    # 2. Is there a way to delete all versions.
    # 3. If I delete the root version, can I still query for its versions.
    #
    # Feedback: previous_version_id implies that I can upload a version of a
    # version, not just the root.
    #
    # I need a current ID (get the most recent version) and every version
    # including the current one needs a stable ID.
    #
    # Deleting: when I delete a root node, find_versions should continue to
    # work, but find_by with the root node ID and no version ID should NotFound.
  ensure
    f.close
  end
end
