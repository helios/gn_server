defmodule GnServer.Router.Main do
  use Maru.Router
  require GnServer.Cache    


  IO.puts "Setup routing"

  alias GnServer.Data.Store, as: Store
  alias GnServer.Logic.Assemble, as: Assemble

  get "/species" do
    { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
      Store.species
    end
    json(conn, result)
  end

  namespace :groups do
    route_param :species, type: String do
      get do
        { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
          Store.groups(params[:species])
        end
        json(conn, result)
      end
    end
  end

  namespace :group do
    route_param :name, type: String do
      get do
        { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
          [_,group] = Regex.run ~r/(.*)\.json$/, params[:name]
          Assemble.group_info(group)
        end
        json(conn, result )
      end
    end
  end

  namespace :cross do
    route_param :name, type: String do
      get do
        { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
          [_,group] = Regex.run ~r/(.*)\.json$/, params[:name]
          Assemble.group_info(group)
        end
        json(conn, result)
      end
    end
  end

  namespace :datasets do
    route_param :group, type: String do
      get do
        { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
          Store.datasets(params[:group])
        end
        json(conn, result)
      end
    end
  end

  namespace :dataset do
    route_param :dataset_name, type: String do
      get do
        { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
          [_,dataset_name] = Regex.run ~r/(.*)\.json$/, params[:dataset_name]
          Assemble.dataset_info(dataset_name)
        end
        json(conn, result)
      end
    end
  end

  namespace :phenotypes do
    route_param :dataset_name, type: String do
      params do
        optional :start, type: Integer
        optional :stop, type: Integer
      end
      get do
        { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
          [_,dataset_name] = Regex.run ~r/(.*)\.json$/, params[:dataset_name]
          Store.phenotypes(dataset_name,params[:start],params[:stop])
        end
        json(conn, result)
      end
    end
  end

  namespace :phenotype do
    route_param :dataset, type: String do
      route_param :group, type: String do
        route_param :trait, type: String do
          get do
            { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
              [_,trait] = Regex.run ~r/(.*)\.json$/, params[:trait]
              Store.phenotype_info(params[:dataset],trait,params[:group])
            end
            json(conn, result)
          end
        end
      end
    end
  end

  namespace :phenotype do
    route_param :dataset, type: String do
      route_param :trait, type: String do
        get do
          { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
            [_,trait] = Regex.run ~r/(.*)\.json$/, params[:trait]
            Store.phenotype_info(params[:dataset],trait)
          end
          json(conn, result)
        end
      end
    end
  end

  namespace :genotype do
    route_param :species, type: String do
      namespace :marker do
        route_param :marker, type: String do
          get do
            { status, result } = GnServer.Cache.get :gn_server_cache, conn.request_path do
              [_,marker] = Regex.run ~r/(.*)\.json$/, params[:marker]
              Store.marker_info(params[:species],marker)
            end
            json(conn, result)
          end
        end
      end
    end
  end

  get do
    json(conn, %{"I am": :genenetwork})
  end

  get "/hey" do
    json(conn, %{"I am": :genenetwork})
  end

end
