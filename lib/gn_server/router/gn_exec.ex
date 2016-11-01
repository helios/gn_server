defmodule GnServer.Router.GnExec do
  use Maru.Router

  IO.puts "Setup routing for GnExec REST APIs"

# WIP: run scanone
  get "qtl/scanone/iron.json" do
    result = GnExec.Cmd.ScanOne.cmd("iron")
    # IO.inspect(result)
    json(conn, result)
  end

  # WIP: run pylmm
  get "/qtl/pylmm/iron.json" do
    {retval,token} = GnExec.Cmd.PyLMM.cmd("iron")
    json(conn, %{ "retval": retval, "token": token})
  end

  get do
    version = Application.get_env(:gn_server, :version)
    json(conn, %{"I am": :genenetwork, "version": version })
  end

  get "/hey" do
    version = Application.get_env(:gn_server, :version)
    json(conn, %{"I am": :genenetwork, "version": version })
  end

   namespace :gnexec do
    namespace :program do
      route_param :token, type: String do
        get "status.json" do
          static_path = Application.get_env(:gn_server, :static_path_prefix)
          status_path = Path.join(static_path, params[:token])
          status = case File.exists?(status_path) do
            false -> %{error: :invalid_token}
            true ->
              status_path_file = Path.join(status_path, "status.json")
              Poison.Parser.parse!(File.read!(status_path_file),keys: :atoms!)
          end
          json(conn, status)
        end #get status.json

        desc "Update a status"
        params do
          requires :progress, type: Integer
        end
        put "status.json" do
          static_path = Application.get_env(:gn_server, :static_path_prefix)
          status_path = Path.join(static_path, params[:token])
          response = case File.exists?(status_path) do
            false -> %{error: :invalid_token}
            true ->
              status_path_file = Path.join(status_path, "status.json")
              File.write(status_path_file, Poison.encode!(%{progress: params[:progress]}), [:binary])
              %{token: params[:token], progress: params[:progress] }
          end

          json(conn, response)
        end

        get "results.json" do
        end

        get "STDOUT" do
        end

        desc "Update STDOUT appending to the end"
        params do
          requires :stdout, type: String
        end
        put "STDOUT" do
          static_path = Application.get_env(:gn_server, :static_path_prefix)
          token_path = Path.join(static_path, params[:token])
          response = case File.exists?(token_path) do
            false -> %{error: :invalid_token}
            true ->
              file_path = Path.join(token_path, "STDOUT")
              File.write!(file_path, params[:stdout], [:binary, :append])
              %{token: params[:token], status: "stdout updated" }
          end

          json(conn, response)
        end

        desc "Update retval"
        params do
          requires :retval, type: String
        end
        put "retval.json" do
          static_path = Application.get_env(:gn_server, :static_path_prefix)
          token_path = Path.join(static_path, params[:token])
          response = case File.exists?(token_path) do
            false -> %{error: :invalid_token}
            true ->
              file_path = Path.join(token_path, "retval.json")
              # IO.puts params[:retval]
              File.write!(file_path, Poison.encode!(%{retval: params[:retval]}), [:binary])
              %{token: params[:token], retval: params[:retval] }
          end

          json(conn, response)
        end


        desc "Upload files"
        params do
          requires :file, type: File
          requires :checksum, type: String
          optional :single, type: Boolean # This parameters is used when the client wants to transfer just a single file and not the whole archive into the job directory
          # exactly_one_of [:file, :checksum]
        end
        post do
          static_path = Application.get_env(:gn_server, :static_path_prefix)
          token_path = Path.join(static_path, params[:token])
          response = case File.exists?(token_path) do
            false -> %{error: :invalid_token}
            true ->
              file = params[:file]
              # TODO compute the checksum for the uploaded file, it is not possible to know tht size of the file at priori
              checksum_remote = params[:checksum]
              case GnExec.Md5.file(file.path) do
                {:ok, checksum_local} ->
                  if checksum_remote == checksum_local do
                    # Assuming that the file is an archive by default that must be decompressed in the
                    # TODO: validate that file is a tar gzipped archive
                    if params[:single] do
                      File.cp!(file.path,Path.join(token_path, file.filename))
                    else
                      System.cmd("tar", ["--strip-components=1","-C", token_path, "-xzvf", file.path] )
                    end

                    %{token: params[:token], sync: "ok"}
                  else
                    %{token: params[:token], sync: "echecksum"}
                  end
                {:error, reason}   ->
                  %{token: params[:token], sync: reason}
              end
            end
            json(conn, response)
        end #uploads


      end # token

    end #program


#deprecated
    # route_param :command, type: String do
    #   get "dataset.json" do
    #     static_path = Application.get_env(:gn_server, :static_path_prefix)
    #     case GnExec.Job.validate(params[:command]) do
    #       {:error, :noprogram } -> json(conn, %{error: :noprogram})
    #       {:ok, module } ->
    #         job = GnExec.Job.new(params[:command])
    #         path = Path.join(static_path, job.token)
    #         File.mkdir_p(path)
    #         File.touch!(Path.join(path,"STDOUT"))
    #         File.touch!(Path.join(path,"status.json"))
    #         json(conn, job)
    #     end
    #   end
    # end

      get do
        static_path = Application.get_env(:gn_server, :static_path_prefix)
        case GnExec.Queue.pop do
          :empty -> json(conn, :empty)
          {:value, job} ->
            path = Path.join(static_path, job.token)
            File.mkdir_p(path)
            File.touch!(Path.join(path,"STDOUT"))
            File.touch!(Path.join(path,"status.json"))
            json(conn, job)
        end
      end


    desc "Place a new job in the queue"
    params do
      requires :token, type: String
      requires :arguments, type: String
    end
    route_param :command, type: String do
      post do
        case GnExec.Job.validate(params[:command]) do
          {:error, :noprogram } -> json(conn, %{error: :noprogram})
          {:ok, module } ->
            job = GnExec.Job.new(params[:command], String.split(params[:arguments], " "))
            if job.token == params[:token] do
              result =  GnExec.Queue.push job
              json(conn, result)
            else
              json(conn, "etokenmismatch")
            end
        end
      end
    end


   end # gnexec


end
