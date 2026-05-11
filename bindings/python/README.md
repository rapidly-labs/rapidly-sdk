# Audio enhancement in Python with the Rapidly engine

> ⚠️ **Note:** We’re currently experiencing issues on some Windows machines. Our team is aware of the problem and working on a fix. Thank you for your patience.

The **Rapidly** Engine is a model inference library built with audio in mind. A large set of pre-trained models ranging from speech noise supression and de-reverberation to stem separation and recovery of missing frequency content are available.

Our models are trained specifically for real-time usage, achieving low latencies down to 20 milliseconds in speech enhancement applications. Furthermore, the models are designed to be small and resource-efficient, with model file sizes down to 242 KB for the smallest noise suppression model.

The Rapidly engine is built in C++ and is compatible across various architectures. With our Python wrapper, you can easily integrate Rapidly into your Python projects and quickly process files and benchmark our models.

If you're looking for a way to quickly test our models, we recommend downloading the [Rapidly Model Player for Mac and Windows](https://rapidly.io/downloads)

To learn more about Rapidly, visit [Rapidly](https://rapidly.io).

Read more about the different models here: [<public-sdk-repo-url>)


## Installation

To install the Python wrapper for Rapidly, use `pip`:

    python -m pip install rapidly

Rapidly is compatible with Python 3 and later.

## How to Use

The Rapidly Python API is a wrapper around the C++ library. 

For those eager to dive in, the `examples.py` script in our PythonAPI GitHub repository is the perfect starting point. This script features a command-line interface that simplifies the process of experimenting with our models. You can quickly test out various audio separation models without writing a single line of code. Here's how to get started:

1. First, clone or download the [examples.py](<public-sdk-repo-url>) file from GitHub to your local machine. 
2. Open your terminal or command prompt and navigate to the directory where you downloaded the file.
3. Execute `python examples.py` to access the command-line interface. Follow the on-screen instructions to select and run audio separation models.

## Using the API

To use the API, import it and list the available models:

    import rapidly
    models = rapidly.list_models()
    print(models)


To download and update to the latest models, simply call:
    
    rapidly.update_models()

## Process a File

To process a file with Rapidly, you can use the `process_file` function as follows:

    import rapidly

    # Initialize RapidlyEngine and create processor
    rapidly_engine = rapidly.RapidlyEngine()

    # List the available models in the models folder.
    models = rapidly.list_models()

    # Many Rapidly models support multiple outputs, and they can be mixed as preferred.
    # There are models that let you adjust reverb and noise reduction separately,
    # as well as stem separation allowing you, for instance, to output just vocals,
    # or perhaps mix drums and guitar.

    # Create a dummy processor to list the available output busses.
    processor = rapidly_engine.create_processor(selected_model, 2, 44100)

    # List available output buses
    num_buses = processor.get_number_of_output_buses()
    bus_names = []
    for i in range(num_buses):
        bus_names.append(processor.get_output_bus_name(i))

    # The bus_names list will show you the name of the available output buses.

    rapidly.process_file(
        model_file_path=selected_model[0],  # Selecting the first model in the list
        input_file_path=input_file_path,
        output_file_path=out_file_path,
        selected_output_bus=0  # Selecting output bus 0, which will be the processed result in most models.
    )

This will apply the enhancement model specified by `models[0]` to the input file located at `input_file_path`, and save the enhanced audio to the output file at `output_file_path`. 

### Models
The models in the **models** folder use clear, descriptive names. For example, `speech-denoise-32ms.v1.0.rapidly` indicates a model designed to _denoise_ speech with a latency of 32 ms. The `micro` size variant (e.g. `speech-denoise-micro-32ms.v1.0.rapidly`) is a compact build of the same model for CPU-constrained scenarios. For product details, visit [Rapidly Labs](https://rapidly.io/).

All models within a family (for example, the **speech-denoise** family) share similar characteristics. For general denoising, we recommend starting with `speech-denoise-96ms.v1.0.rapidly` to check if it meets your needs, and moving down to shorter latency variants if needed.  

If you have specific requirements or challenging audio conditions, we can build customized models optimized for your use case—feel free to contact us to discuss options.

Please note that rapidly.process_file is using PySoundFile to read and write audio files. While PySoundFile is not a requirement for using Rapidly, it is a convenient library for handling audio files in Python.

For more information and examples on using Rapidly, see the [Rapidly documentation](https://rapidly.io/docs/welcome).
