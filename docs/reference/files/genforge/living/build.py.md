# genforge/living/build.py

Builds immutable, hashed local candidate review directories from validated
release JSON and existing art. Produces atlases, grounded briefs, portable review,
C++ effect bytecode and manifest. Existing output is hash-verified before reuse.

Narrative dependencies, including pinned transitive chapters, are hashed into
sources. Narrative schema/module changes affect build identity. brief() includes
current story contracts and actual earlier stories for grounded authoring.
No network/model generation; generate.py is a separately explicit provider step.
Technical success keeps publishable=false pending art/animation/runtime review.
Gates: test_living.py and test_narrative.py; tech/34 owns commands and budgets.
