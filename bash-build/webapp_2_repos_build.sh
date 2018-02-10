#!/bin/bash
##Program: webapp_2_repos_build.sh
##Author: Amal-J <Amal Jith>
##Parameters: 1. python_repo_location  2. python_repo_branch_name  3. ruby_repo_location  4. ruby_repo_branch_name
## About: ########
#This script will build code from two different git repositories: python_repo & ruby_repo.
#Project name: Innovative Webapp
#PYTHN_REPO="/home/ubuntu/python-webapp-dev"
#PYTHN_REPO_BRANCH_NM="release-1.1"
#RUBY_REPO="/home/ubuntu/ruby-app-dev"
#RUBY_REPO_BRANCH_NM="master"
###################
##UDFs for script activity logging - for debugging purpose.
logSCREEN () {
  printf "$*\n"
}

logDEBUG () {
  printf "$*\n" >> $LOG_FILE
}

logBOTH () {
  logSCREEN "$*"
  logDEBUG "$*"
}
#--------------------------------------------------------------------------------------------
prepare-repositories () {
	if [[ ! -d $PYTHN_REPO || ! -d $RUBY_REPO ]]; then
		logBOTH "One or more mandatory repositories not present"
		logBOTH "++ BUILD PROCESS ABORTED ++"
		exit 5
	fi
    #Checkout and prepare all needed repos for build 
    logBOTH "Commencing Build for all repos - This may take a few minutes.."
	function reset-repo-pull-fresh-code () {
		logBOTH "Repository is: `pwd`"
		PASSED_BRANCH=$1
		sudo git fetch --all
		logBOTH "Branch is: ${PASSED_BRANCH}"
		sudo git checkout ${PASSED_BRANCH}
		sudo git reset --hard origin/${PASSED_BRANCH}
		sudo git -c core.quotepath=false fetch origin --progress --prune
	  	#sudo git rebase
		#sudo git pull origin ${PASSED_BRANCH}
	}

	cd $PYTHN_REPO
 	reset-repo-pull-fresh-code
    PYTHN-BRANCH=`git branch | grep \* | cut -d ' ' -f2 | sed -r 's/[.]+/-/g'`
    logBOTH "PYTHN_REPO BRANCH IS: ${PYTHN-BRANCH}"
    PYTHN-ID="PY-${PYTHN-BRANCH}-"`git log --format="%H" -n 1 | awk '{print substr($0,0,8)}'`
    logBOTH "PYTHN_REPO BUILD ID IS:  ${PYTHN-ID}"

    cd $RUBY_REPO
	reset-repo-pull-fresh-code
    RUBY-BRANCH=`git branch | grep \* | cut -d ' ' -f2 | sed -r 's/[.]+/-/g'`
    logBOTH "RUBY_REPO BRANCH IS: ${RUBY-BRANCH}"
    RUBY-ID="RB-${RUBY-BRANCH}-"`git log --format="%H" -n 1 | awk '{print substr($0,0,8)}'`
    logBOTH "RUBY_REPO BUILD ID IS: ${RUBY-ID}"

    BUILD_ID="${DATE_TIME}-${PYTHN-ID}-${RUBY-ID}"
    ##03Feb17-1267  -  PY-master-e50895c7  -  RB-release-1-1-13f189f9
}
	
#--------------------------------------------------------------------------------------------

create-stage-and-build () {

	cd $SCRIPT_LAUNCH_DIR
	STAGE_DIR="${SCRIPT_LAUNCH_DIR}/${BUILD_ID}"
	BUILD_DIR="${SCRIPT_LAUNCH_DIR}"/generated-builds
	FINAL_STAGE="${SCRIPT_LAUNCH_DIR}"/FINAL_STAGE
	
	logBOTH "STAGING area is : ${STAGE_DIR}"
	logBOTH "PYTHN REPOSITORY IS : $PYTHN_REPO"
	logBOTH "RUBY REPOSITORY IS : $RUBY_REPO"
	logBOTH "Creating the staging area directory at :${STAGE_DIR}"

	mkdir $BUILD_ID
	mkdir -p "${STAGE_DIR}"
	if [ ! -d "${STAGE_DIR}" ]; then
	   logBOTH "Cannot create the Directory at: '${STAGE_DIR}'."
	   logBOTH "ERROR: EXITING.."
	   exit 2
	fi

	mkdir -p "${BUILD_DIR}"
	if [ ! -d "${BUILD_DIR}" ]; then
	   logBOTH "Cannot create the Directory at: '${BUILD_DIR}'."
	   logBOTH "ERROR: EXITING.."
	   exit 3
	fi

	mkdir -p "${FINAL_STAGE}"
	if [ ! -d "${FINAL_STAGE}" ]; then
	   logBOTH "Cannot create the Directory at: '${FINAL_STAGE}'."
	   logBOTH "ERROR: EXITING.."
	   exit 4
	fi

	logBOTH "Copying artifacts to Stage dir"
	mkdir -p ${STAGE_DIR}/Innovative-Webapp-flask-server
	mkdir -p ${STAGE_DIR}/plugin
	mkdir -p ${STAGE_DIR}/scripts
	sudo chmod -R 777 ${STAGE_DIR}
	cp -ar $PYTHN_REPO/Innovative-Webapp/app.py ${STAGE_DIR}/Innovative-Webapp-flask-server
	cp -ar $PYTHN_REPO/Innovative-Webapp/flask ${STAGE_DIR}/Innovative-Webapp-flask-server/
	cp -ar $PYTHN_REPO/Innovative-Webapp/svr_flsk_chk.conf ${STAGE_DIR}/Innovative-Webapp-flask-server/
	cp -ar $PYTHN_REPO/Innovative-Webapp/start_flask_cron.sh ${STAGE_DIR}/Innovative-Webapp-flask-server/
	cp -ar $RUBY_REPO/* ${STAGE_DIR}/plugin/
	cp -ar $PYTHN_REPO/Innovative-Webapp/scripts/* ${STAGE_DIR}/scripts/

	logBOTH "Finished assembling the staging area at : ${STAGE_DIR}"
	logBOTH "Creating INNOVATIVE_WEBAPP.tar.gz tarball from staging"
	#First tar including all deployment artifacts
	tar czf "INNOVATIVE_WEBAPP.tar.gz" $BUILD_ID
	
	logBOTH "Copying to final tarball staging area at ${FINAL_STAGE}"
	##cp "INNOVATIVE_WEBAPP.tar.gz" ${BUILD_DIR}
	cp "INNOVATIVE_WEBAPP.tar.gz" ${FINAL_STAGE}	
	sudo rm -f "INNOVATIVE_WEBAPP.tar.gz"
	cp -ar $PYTHN_REPO/Innovative-Webapp-flask-server/Webapp-scripts/Webapp-cluster-deploy.sh ${FINAL_STAGE}
	cp -ar $PYTHN_REPO/Innovative-Webapp-flask-server/Webapp-scripts/check-status-elk.sh ${FINAL_STAGE}
		
	cd ${FINAL_STAGE}
	logBOTH "Creating the final tarball: InnovativeWebappBuild-${BUILD_ID}.tar.gz"
	tar czf "InnovativeWebappBuild-${BUILD_ID}.tar.gz" *
	echo $?

	echo "InnovativeWebappBuild-${BUILD_ID}.tar.gz" > latest-build-info.txt
	cp "InnovativeWebappBuild-${BUILD_ID}.tar.gz" ${BUILD_DIR}
	cp latest-build-info.txt ${BUILD_DIR}
	
	cd ${BUILD_DIR}
	sudo rm -rf ${FINAL_STAGE}
	sudo rm -rf ${STAGE_DIR}
}
#-------------------------------------------------------------------------------------------
#--------------------------- EXECUTION STARTS FROM HERE ------------------------------------
#-------------------------------------------------------------------------------------------
#User defined parameters
PYTHN_REPO=$1
PYTHN_REPO_BRANCH_NM="$2"
RUBY_REPO=$3
RUBY_REPO_BRANCH_NM="$4"
SCRIPT_LAUNCH_DIR=`pwd`
DATE_TIME=$(date +"%d%b%y-%H%M")
BUILD_ID="${DATE_TIME}"
STAGE_DIR="${SCRIPT_LAUNCH_DIR}/${BUILD_ID}"
BUILD_DIR="${SCRIPT_LAUNCH_DIR}/generated-builds"
FINAL_STAGE="${SCRIPT_LAUNCH_DIR}/FINAL_STAGE"
BUILD_TARBALL="$SCRIPT_LAUNCH_DIR/INNOVATIVE_WEBAPP"
LOG_DIR="${SCRIPT_LAUNCH_DIR}/innovative-webapp-build-logs"
#-------------------------------------------------------------------------------------------
mkdir -p "${LOG_DIR}"
if [ ! -d "${LOG_DIR}" ]; then
  echo "Cannot create directory at: ${LOG_DIR}"
  echo "ERROR: EXITING.."
  exit 1
fi
LOG_FILE="${LOG_DIR}/build-log-${DATE_TIME}.txt"
touch "$LOG_FILE"
#--------------------------------------------------------------------------------------------
logSCREEN "Logging to screen from here.."
logDEBUG "++ Innovative Webapp Build Process initiated at $DATE_TIME ++"
logBOTH "Currently in `pwd`"
logBOTH "Getting the repos prepared for build"
prepare-repositories
logBOTH "BUILD_ID is : ${BUILD_ID}"
#--------------------------------------------------------------------------------------------
logBOTH "Initiating actual build process"
create-stage-and-build
logBOTH "+++ Innovative Webapp Build Process Finished  +++"
logSCREEN "End of webapp_2_repos_build.sh at `date`"
#--------------------------------------END---------------------------------------------------
