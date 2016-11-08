defmodule GnServer.Router.GnExec do
  use Maru.Router
  require Logger

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
        get "progress.json" do
          json(conn, GnExec.Registry.progress(:read, params[:token]))
        end #get status.json

        desc "Update a progress"
        params do
          requires :progress, type: Integer
        end
        put "progress.json" do
          token = params[:token]
          {:ok, {job, status}} = GnExec.Registry.get(token)
          if :ok == GnExec.Registry.mark(token, :running) do
              GnExec.Job.setupdir(job)# Create the directories before setting the stare to running
          end
          GnExec.Registry.progress(:write, token, params[:progress])
          json(conn, :updated)
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
          # It should not be possible to change state if it is not :queued
          if :ok == GnExec.Registry.mark(params[:token], :running) do
            {:ok, {job, status}} = GnExec.Registry.get params[:token]
            GnExec.Job.setupdir(job)
          end
          GnExec.Registry.stdout(:write, params[:token], params[:stdout])
          response = %{token: params[:token], status: "stdout updated" }
          json(conn, response)
        end

        desc "Update retval"
        params do
          requires :retval, type: String
        end
        put "retval.json" do
          response = case GnExec.Registry.get(params[:token]) do
            {:ok, {job, :transferred}} ->
              GnExec.Registry.retval(:write, params[:token], params[:retval])
              GnExec.Registry.complete(params[:token])
              %{result: :ok, info: :completed}
            {:ok, {job, status}} ->
              Logger.debug "Error token #{job.token} has status #{status}."
              %{result: :error, info: status}
            # remember that :enot means not exists
            :error ->
              Logger.debug "Error token #{params[:token]} does not exist."
              %{result: :error, info: :note}
            end
          json(conn, %{token: params[:token], retval: params[:retval], reply: response })
        end


        desc "Upload files"
        params do
          requires :file, type: File
          requires :checksum, type: String
          optional :single, type: Boolean # This parameters is used when the client wants to transfer just a single file and not the whole archive into the job directory
          # exactly_one_of [:file, :checksum]
        end
        post do
          static_path = Application.get_env(:gn_exec, :jobs_path_prefix)
          token_path = Path.join(static_path, params[:token])
          # IO.inspect params
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
                    if :ok == GnExec.Registry.mark(params[:token], :running) do
                      {:ok, {job, status}} = GnExec.Registry.get params[:token]
                      GnExec.Job.setupdir(job)
                    end

                    if params[:single] do
                      File.cp!(file.path,Path.join(token_path, file.filename))
                    else
                      {:ok, devnull} = File.open "/dev/null", [:write]
                      System.cmd("tar", ["--strip-components=1","-C", token_path, "-xzvf", file.path], stderr_to_stdout: true, into: IO.stream(devnull, :line))
                      File.close devnull
                    end
                    GnExec.Registry.transferred params[:token]
                    %{token: params[:token], sync: "ok"}
                  else
                    GnExec.Registry.error params[:token]
                    %{token: params[:token], sync: "echecksum"}
                  end
                {:error, reason}   ->
                  %{token: params[:token], sync: reason}
              end
            end
            # IO.inspect response
            json(conn, response)
        end #uploads


      end # token

    end #program

    desc "Get a job form the Queue, it's FIFO. Job transit from :queued status to :requested and the directories are prepared to accept the job data."
    get do
        case GnExec.Registry.next do
          :empty -> json(conn, :empty)
          {job, status} ->
            json(conn, job)
        end
      end


    desc "Place a new job in the queue (submit)"
    params do
      requires :token, type: String
      requires :arguments, type: String
    end
    route_param :command, type: String do
      post do

        case GnExec.Job.validate(params[:command]) do
          {:error, :noprogram } -> json(conn, %{error: :noprogram})
          {:ok, module } ->
            {:ok, job} = GnExec.Job.new(params[:command], String.split(params[:arguments]))
            if job.token == params[:token] do
              GnExec.Registry.put job # does not return anything, check the status
              json(conn, GnExec.Registry.status(job.token))
            else
              json(conn, "etokenmismatch")
            end
        end
      end
    end


   end # gnexec


end
