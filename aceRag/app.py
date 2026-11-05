import modal

app = modal.App("ace-rag")

# Register all services when deploying from the local machine.
#
# Inside a remote container, Modal imports the service module it needs.
# Importing app here should provide the shared App object without also
# importing unrelated services and their dependencies.
if modal.is_local():
    import modal_compute
    import vector_store