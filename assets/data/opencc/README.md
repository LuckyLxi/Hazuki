# Chinese conversion dictionaries

Source: [OpenCC 1.1.9](https://github.com/BYVoid/OpenCC/tree/ver.1.1.9/data/dictionary).
The four `.txt` dictionaries are unmodified upstream files, licensed under
Apache-2.0; see `LICENSE` in this directory.

Hazuki uses longest matching phrases before individual characters, selecting the
first candidate when an entry lists multiple forms. This is a lightweight display
converter using OpenCC data, not the OpenCC segmentation engine. No regional
vocabulary substitution is applied.
