unless RUBY_VERSION == '2.4.0'
  ::Mongo::Logger.logger.level = ::Logger::FATAL

  RSpec.shared_examples 'mongo importer' do
    it_behaves_like 'daru dataframe'
    its(:nrows)             { is_expected.to eq(nrows)             }
    its(:ncols)             { is_expected.to eq(ncols)             }
    its('vectors.to_a')     { is_expected.to match_array(vector)   }
    its('index.to_a.last')  { is_expected.to eq(last_index)        }
    its('index.to_a.first') { is_expected.to eq(first_index)       }
  end

  # @note
  #
  #   Mongo gem faces the 'wrong argument type, Expected Proc' bug prelavent in
  #   Ruby 2.4.0, whose origin is in MRI 2.4.0. This seems to have been fixed
  #   in Ruby 2.4.1 release.
  #
  #   Signed off by @athityakumar on 19/06/2017 at 11:55PM IST.
  RSpec.describe Daru::IO::Importers::Mongo do
    let(:connection)    { ::Mongo::Client.new('mongodb://127.0.0.1:27017/test') }
    let(:collection)    { path.split('json').last.tr('/.','').to_sym            }
    let(:index)         { nil                                                   }
    let(:order)         { nil                                                   }
    let(:skip)          { nil                                                   }
    let(:limit)         { nil                                                   }
    let(:filter)        { nil                                                   }
    let(:first_index)   { 0                                                     }
    let(:last_index)    { nil                                                   }
    let(:first_vector)  { nil                                                   }
    let(:last_vector)   { nil                                                   }
    let(:columns)       { nil                                                   }
    let(:named_columns) { {}                                                    }

    def store(path)
      collection = path.split('json').last.tr('/.','').to_sym
      documents = ::JSON.parse(File.read(path))
      if documents.is_a?(Array)
        connection[collection].insert_many(documents)
      else
        connection[collection].insert_one(documents)
      end
    end

    before { store path                  }
    after  { connection[collection].drop }

    subject do
      described_class.new(
        connection,
        collection,
        *columns,
        order: order,
        index: index,
        filter: filter,
        skip: skip,
        limit: limit,
        **named_columns
      ).call
    end

    context 'on simple json file' do
      context 'in NASA data' do
        let(:path)       { 'spec/fixtures/json/nasadata.json' }
        let(:nrows)      { 202                                }
        let(:ncols)      { 11                                 }
        let(:last_index) { 201                                }
        let(:vector) do
          %w[_id designation discovery_date h_mag i_deg moid_au orbit_class period_yr pha q_au_1 q_au_2]
        end

        context 'without xpath (simple json)' do
          it_behaves_like 'mongo importer'
        end

        context 'fetches paginated results - first page' do
          let(:limit)      { 30 }
          let(:nrows)      { 30 }
          let(:last_index) { 29 }

          it_behaves_like 'mongo importer'
        end

        context 'fetches paginated results - last page' do
          let(:skip)       { 180 }
          let(:limit)      { 30  }
          let(:nrows)      { 22  }
          let(:last_index) { 21  }

          it_behaves_like 'mongo importer'
        end

        context 'fetches results with filter' do
          let(:filter)     { {pha: :N} }
          let(:limit)      { 200       }
          let(:nrows)      { 151       }
          let(:last_index) { 150       }

          it_behaves_like 'mongo importer'
        end

        context 'fetches results with filter and pagination' do
          let(:filter)     { {pha: :N} }
          let(:limit)      { 100       }
          let(:nrows)      { 100       }
          let(:last_index) { 99        }

          it_behaves_like 'mongo importer'
        end
      end
    end

    it_behaves_like 'importer with json-path option'
  end
end
