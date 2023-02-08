using Pkg
Pkg.offline()
Pkg.activate(".")
Pkg.instantiate()

run_benchmark(n_rounds) = 
    @timed pigeons(;
        target = toy_mvn_target(100), 
        checkpoint = false, 
        recorder_builders = [],
        n_rounds)

commit = readline("commit")
date = replace(read(`git show -s --format=%ct $commit`, String), "\n" => "")
in_master = 
    contains(
        read(`git branch --contains $commit`, String),
        "master"
    )
write(
    "info.tsv", 
    """
    commit\t$commit
    date\t$date
    in_master\t$in_master
    """
)

write_header(io) = write(io, "n_rounds,time,bytes\n")
write_result(io, n_rounds, timed) = write(io, "$n_rounds,$(timed.time),$(timed.bytes)\n")

using_timed = @timed using Pigeons

open("stats.csv", "w") do io
    write_header(io)

    # time for calling using
    write_result(io, 0, using_timed)

    run_benchmark(10) # "burn-in"
    for n_rounds in 1:15 
        timed = run_benchmark(n_rounds)
        write_result(io, n_rounds, timed)
    end
end