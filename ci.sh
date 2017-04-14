#!/usr/bin/env bash

### OSS CI CONTEXT VARIABLES BEGIN
if [ -n "${CI_BUILD_REF_NAME}" ] && ([ "${CI_BUILD_REF_NAME}" == "master" ] || [ "${CI_BUILD_REF_NAME}" == "develop" ]); then BUILD_SCRIPT_REF="${CI_BUILD_REF_NAME}"; else BUILD_SCRIPT_REF="develop"; fi
if [ -z "${GIT_SERVICE}" ]; then
    if [ -n "${CI_PROJECT_URL}" ]; then INFRASTRUCTURE="internal"; GIT_SERVICE=$(echo "${CI_PROJECT_URL}" | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,'); else INFRASTRUCTURE="local"; GIT_SERVICE="${LOCAL_GIT_SERVICE}"; fi
fi
if [ -z "${GIT_REPO_OWNER}" ]; then
    if [ -n "${TRAVIS_REPO_SLUG}" ]; then
        GIT_REPO_OWNER=$(echo ${TRAVIS_REPO_SLUG} | awk -F/ '{print $1}');
    else
        if [ -z "${INTERNAL_GIT_SERVICE_USER}" ]; then GIT_REPO_OWNER="infra"; else GIT_REPO_OWNER="${INTERNAL_GIT_SERVICE_USER}"; fi
    fi
fi
### OSS CI CONTEXT VARIABLES END

export BUILD_PUBLISH_DEPLOY_SEGREGATION="true"
export BUILD_SITE="true"
# for github ,this will used for sub dir on home1-oss/home1-oss#gh-pages
export BUILD_SITE_PATH_PREFIX=""
export BUILD_SITE_GITHUB_REPOSITORY_OWNER="home1-oss"
export BUILD_SITE_GITHUB_REPOSITORY_NAME="home1-oss"
export BUILD_TEST_FAILURE_IGNORE="false"
export BUILD_TEST_SKIP="false"



### OSS CI CALL REMOTE CI SCRIPT BEGIN
echo "eval \$(curl -s -L ${GIT_SERVICE}/${GIT_REPO_OWNER}/oss-build/raw/${BUILD_SCRIPT_REF}/src/main/ci-script/ci.sh)"
eval "$(curl -s -L ${GIT_SERVICE}/${GIT_REPO_OWNER}/oss-build/raw/${BUILD_SCRIPT_REF}/src/main/ci-script/ci.sh)"
### OSS CI CALL REMOTE CI SCRIPT END

$@
