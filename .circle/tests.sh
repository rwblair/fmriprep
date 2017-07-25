#!/bin/bash
#
# Balance fmriprep testing workflows across CircleCI build nodes
#
# Borrowed from nipype

# Setting       # $ help set
set -e          # Exit immediately if a command exits with a non-zero status.
set -u          # Treat unset variables as an error when substituting.
set -x          # Print command traces before executing command.
set -o pipefail # Return value of rightmost non-zero return in a pipeline

if [ "${CIRCLE_NODE_TOTAL:-}" != "2" ]; then
  echo "These tests were designed to be run at 2x parallelism."
  exit 1
fi

# Only run docs if DOCSONLY or "docs only" (or similar) is in the commit message
if echo $GIT_COMMIT_DESC | grep -Pi 'docs[ _]?only'; then
    case ${CIRCLE_NODE_INDEX} in
        0)
          docker run -ti --rm=false -v $HOME/docs:/_build_html --entrypoint=sphinx-build poldracklab/fmriprep:latest \
              -T -E -b html -d _build/doctrees-readthedocs -W -D language=en docs/ /_build_html 2>&1 \
              | tee $HOME/docs/builddocs.log
          cat $HOME/docs/builddocs.log && if grep -q "ERROR" $HOME/docs/builddocs.log; then false; else true; fi
          ;;
    esac
    exit 0
fi


# These tests are manually balanced based on previous build timings.
# They may need to be rebalanced in the future.
case ${CIRCLE_NODE_INDEX} in
  0)
    fmriprep-docker -i poldracklab/fmriprep:latest --config $HOME/nipype.cfg -w $HOME/ds054/scratch $HOME/data/ds054 $HOME/ds054/out participant --no-freesurfer --debug --write-graph --force-syn
    find ~/ds054/scratch -not -name "*.svg" -not -name "*.html" -not -name "*.svg" -not -name "*.rst" -type f -delete
    ;;
  1)
    docker run -ti --rm=false --entrypoint="python" poldracklab/fmriprep:latest -m unittest discover test
    docker run -ti --rm=false -v $HOME/docs:/_build_html --entrypoint=sphinx-build poldracklab/fmriprep:latest \
        -T -E -b html -d _build/doctrees-readthedocs -W -D language=en docs/ /_build_html 2>&1 \
        | tee $HOME/docs/builddocs.log
    cat $HOME/docs/builddocs.log && if grep -q "ERROR" $HOME/docs/builddocs.log; then false; else true; fi
    fmriprep-docker -i poldracklab/fmriprep:latest --help
    fmriprep-docker -i poldracklab/fmriprep:latest --config $HOME/nipype.cfg -w $HOME/ds005/scratch $HOME/data/ds005 $HOME/ds005/out participant --debug --write-graph --use-aroma --ignore-aroma-denoising-errors
    find ~/ds005/scratch -not -name "*.svg" -not -name "*.html" -not -name "*.svg" -not -name "*.rst" -type f -delete
    ;;
esac

