#!/usr/bin/env bash

if [ -f codesigning.asc.enc ] && [ "${TRAVIS_PULL_REQUEST}" == 'false' ]; then
    openssl aes-256-cbc -K $encrypted_f1fe46eea14b_key -iv $encrypted_f1fe46eea14b_iv -in codesigning.asc.enc -out codesigning.asc -d
    gpg --fast-import codesigning.asc
fi

### OSS CI CONTEXT VARIABLES BEGIN
if ([ -z "${CI_BUILD_REF_NAME}" ] && [ -n "${TRAVIS_BRANCH}" ]); then CI_BUILD_REF_NAME="${TRAVIS_BRANCH}"; fi
if [ -n "${OSS_BUILD_REF_BRANCH}" ]; then BUILD_SCRIPT_REF="${OSS_BUILD_REF_BRANCH}"; else BUILD_SCRIPT_REF="develop"; fi
if [ -z "${OSS_BUILD_CONFIG_REF_BRANCH}" ]; then export OSS_BUILD_CONFIG_REF_BRANCH="develop"; fi
if [ -z "${GIT_SERVICE}" ]; then
    if [ -n "${CI_PROJECT_URL}" ]; then INFRASTRUCTURE="internal"; GIT_SERVICE=$(echo "${CI_PROJECT_URL}" | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,'); else INFRASTRUCTURE="local"; GIT_SERVICE="${LOCAL_GIT_SERVICE}"; fi
fi
if [ -z "${GIT_REPO_OWNER}" ]; then
    if [ -n "${TRAVIS_REPO_SLUG}" ]; then
        GIT_REPO_OWNER=$(echo ${TRAVIS_REPO_SLUG} | awk -F/ '{print $1}');
    else
        if [ -z "${INTERNAL_GIT_SERVICE_USER}" ]; then GIT_REPO_OWNER="home1-oss"; else GIT_REPO_OWNER="${INTERNAL_GIT_SERVICE_USER}"; fi
    fi
fi
### OSS CI CONTEXT VARIABLES END

export BUILD_PUBLISH_DEPLOY_SEGREGATION="false"
export BUILD_SITE="true"
export BUILD_SITE_PATH_PREFIX="oss"
export BUILD_HOME1_OSS_OWNER="home1-oss"
export BUILD_SITE_GITHUB_REPOSITORY_OWNER="${BUILD_HOME1_OSS_OWNER}"
export BUILD_SITE_GITHUB_REPOSITORY_NAME="home1-oss"
export BUILD_TEST_FAILURE_IGNORE="false"
export BUILD_TEST_SKIP="false"



### OSS CI CALL REMOTE CI SCRIPT BEGIN
echo "eval \$(curl -s -L ${GIT_SERVICE}/${GIT_REPO_OWNER}/oss-build/raw/${BUILD_SCRIPT_REF}/src/main/ci-script/ci.sh)"
eval "$(curl -s -L ${GIT_SERVICE}/${GIT_REPO_OWNER}/oss-build/raw/${BUILD_SCRIPT_REF}/src/main/ci-script/ci.sh)"
### OSS CI CALL REMOTE CI SCRIPT END

# home1-oss && not pr trigger will on condition
if ([ "${GIT_REPO_OWNER}" == "${BUILD_HOME1_OSS_OWNER}" ] && [ "pull_request" != "${TRAVIS_EVENT_TYPE}" ]); then
    case "$CI_BUILD_REF_NAME" in
        "develop")
            export BUILD_PUBLISH_CHANNEL="snapshot";
            $@
            ;;
        release*)
            export BUILD_PUBLISH_CHANNEL="release";
            if [ "${1}" == "publish_snapshot" ]; then
                publish_release ;
            elif [ "${1}" == "analysis" ]; then
                echo "skip analysis as not at develop branch";
            else
                $@;
            fi
            ;;
        feature*|hotfix*|"master"|*)
            if [ "${1}" == "test_and_build" ]; then $@ ; fi
            echo "on this condition only trigger test_and_build,CI_BUILD_REF_NAME=${CI_BUILD_REF_NAME}"
            ;;
    esac
else
    # the fork project only trigger test_and_build
    if [ "${1}" == "test_and_build" ]; then $@; fi
fi
