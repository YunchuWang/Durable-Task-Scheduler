import azure.functions as func
import azure.durable_functions as df
import logging
import string

myapp = df.DFApp(http_auth_level=func.AuthLevel.ANONYMOUS)


def generate_large_payload(size_kb: int) -> dict:
    """Generate a payload of approximately size_kb kilobytes."""
    chars = string.ascii_letters + string.digits
    padding = (chars * ((size_kb * 1024) // len(chars) + 1))[: size_kb * 1024]
    return {"data": padding, "size_kb": size_kb}


@myapp.orchestration_trigger(context_name="context")
def fan_out_fan_in_orchestration(context: df.DurableOrchestrationContext):
    """Fan-out/Fan-in orchestration with large payloads (~20KB each)."""
    work_items = [f"item-{i}" for i in range(5)]

    parallel_tasks = []
    for item in work_items:
        task = context.call_activity("process_item", item)
        parallel_tasks.append(task)

    results = yield context.task_all(parallel_tasks)

    total_size = sum(r["size_kb"] for r in results)
    return {
        "items_processed": len(results),
        "total_size_kb": total_size,
        "individual_sizes": [r["size_kb"] for r in results],
    }


@myapp.activity_trigger(input_name="item")
def process_item(item: str) -> dict:
    """Process a single work item and return a ~20KB payload."""
    logging.info(f"Processing: {item}")
    payload = generate_large_payload(20)
    payload["item"] = item
    logging.info(f"Generated payload for {item}: ~{payload['size_kb']}KB")
    return payload


@myapp.route(route="StartFanOutFanIn", methods=["POST"])
@myapp.durable_client_input(client_name="client")
async def start_fan_out_fan_in(req: func.HttpRequest, client) -> func.HttpResponse:
    """HTTP trigger to start the fan-out/fan-in orchestration."""
    instance_id = await client.start_new("fan_out_fan_in_orchestration")
    logging.info(f"Started orchestration: {instance_id}")
    return client.create_check_status_response(req, instance_id)


# Health check endpoint
@myapp.route(route="hello", methods=["GET"])
def hello(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse("Hello from Python DF!", status_code=200)
