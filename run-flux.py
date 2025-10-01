#!/usr/bin/env python3

import argparse
import collections
import concurrent.futures as cf
import json
import os
from functools import partial
from pprint import pprint

import flux
import flux.job
from flux.job import JobspecV1

def parse_input_dir(input: str) -> dict:
    """
    Parse input directory containing Mneme JSON files

    Returns a dictionary containing all the kernels recorded by Mneme
    """
    extracted_data = {}

    for filename in os.scandir(input):
        if filename.name.endswith(".json"):
            try:
                with open(filename.path, "r", encoding="utf-8") as file:
                    data = json.load(file)
                    if "instances" in data:
                        if filename.name not in extracted_data:
                            extracted_data[filename.name] = list(
                                data["instances"].keys()
                            )
                        else:
                            extracted_data[filename.name] += list(
                                data["instances"].keys()
                            )
            except (json.JSONDecodeError, IOError) as e:
                print(f"Error reading {filename.name}: {e}")

    return extracted_data


def create_jobspec(
    json_file,
    instance,
    exec,
    input_dir,
    suffix="",
    trials=1000,
    iterations=3,
    duration=None,
    extra_opts="",
    db_dir=None,
):
    json_id = str(json_file.split(".")[0])
    extra = ""
    if "specialize" in extra_opts:
        extra = "-spec"
    else:
        extra = "-nospec"
    if not db_dir:
        db_dir = (
            f"result-{json_id}-{str(instance)}-{str(trials)}-{str(iterations)}{extra}"
        )
    duration = str(duration) if duration else duration
    jobspec = flux.job.JobspecV1.from_command(
        command=[
            str(exec),
            str(json_file),
            str(instance),
            str(db_dir),
            str(suffix),
            str(trials),
            str(iterations),
            extra_opts,
        ],
        num_tasks=1,
        num_nodes=1,
        exclusive=True,
        cwd=str(input_dir),
        output=db_dir+"-{{id}}.log",
        duration=duration,  # in secs
    )
    return jobspec


def main():
    parser = argparse.ArgumentParser(
        description="Submit a collection of jobs using Flux. Each job optimizes one kernel using Mneme"
    )
    parser.add_argument(
        "-i",
        "--input",
        type=str,
        required=True,
        help="Directory containing Mneme JSON files",
    )
    parser.add_argument(
        "-m",
        "--max-jobs",
        type=int,
        required=False,
        default=int(os.environ.get("BATCH_NNODES", 1)),
        help="Max number of jobs to run in parallel (1 job = 1 node). Will be equals to BATCH_NNODES if set",
    )
    parser.add_argument(
        "-spec", "--specialize", action="store_true", help="Run with --specialize"
    )
    args = parser.parse_args()

    execution_data = parse_input_dir(args.input)
    # pprint(execution_data)


    print(f"Running with")
    print(f"    --input.     = {args.input}")
    print(f"    --max-jobs   = {args.max_jobs}")
    print(f"    --specialize = {args.specialize}")

    handler = flux.Flux()

    list_jobs = [(k, vv) for k, v in execution_data.items() for vv in v]
    total_jobs = len(list_jobs)

    _create_jobspec = partial(
        create_jobspec,
        exec="/usr/workspace/LExperts/laghos/laghos-loic/laghos-hip/run-bo-all.sh",
        input_dir=args.input,
        suffix="laghos",
        trials=1000,
        iterations=3,
        duration=None,
        extra_opts="--specialize" if args.specialize else "",
    )

    jobspec_queue = collections.deque(_create_jobspec(k, v) for k, v in list_jobs)
    futures = []  # holds incomplete futures
    futures_tojobid = {}  # mapping between job ID and futures
    k = 1
    success = 1
    with flux.job.FluxExecutor() as executor:
        try:
            while jobspec_queue or futures:
                if len(futures) < args.max_jobs and jobspec_queue:
                    job_curr = jobspec_queue.popleft()
                    fut = executor.submit(job_curr)
                    futures.append(fut)
                    futures_tojobid[id(fut)] = fut.jobid()
                    print(f"[{k}/{total_jobs}] Submitted: {futures_tojobid[id(fut)]}")
                    k += 1
                else:
                    done, not_done = cf.wait(futures, return_when=cf.FIRST_COMPLETED)
                    futures = list(not_done)
                    for fut in done:
                        if fut.exception() is not None:
                            print(
                                f"[{success}/{total_jobs}] wait: {futures_tojobid[id(fut)]} Error: job raised error "
                                f"{fut.exception()}"
                            )
                        elif fut.result() == 0:
                            print(f"[{success}/{total_jobs}] wait: {futures_tojobid[id(fut)]} Success")
                        else:
                            print(
                                f"[{success}/{total_jobs}] wait: {futures_tojobid[id(fut)]} Error: job returned "
                                f"exit code {fut.result()}"
                            )
                        success += 1
        except KeyboardInterrupt as _:
            print(f"Caught Ctrl+C.. canceling all jobs")
            cancel_futs = [
                flux.job.cancel_async(handler, job.to_dict()["id"])
                for job in flux.job.JobList(handler, max_entries=100000).jobs()
            ]


if __name__ == "__main__":
    main()
