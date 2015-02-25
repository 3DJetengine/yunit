# -*- Mode: Python; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
#
# Unity Autopilot Test Suite
# Copyright (C) 2014, 2015 Canonical
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

import os
import subprocess
import threading

import fixtures

from autopilot import introspection
from autopilot.matchers import Eventually
from testtools.matchers import Equals
from ubuntuuitoolkit import fixture_setup

from unity8 import process_helpers, sensors
from unity8.shell import emulators
from unity8.shell.emulators import (
    main_window as main_window_emulator
)

class LaunchUnityWithFakeSensors(fixtures.Fixture):

    """Fixture to launch Unity8 with an injectable sensors backend.

    :ivar unity_proxy: The Autopilot proxy object for the Unity shell.

    """

    unity_proxy = None
    main_win = None

    def setUp(self):
        """Restart Unity8 with testability and create sensors."""
        super(LaunchUnityWithFakeSensors, self).setUp()
        self.useFixture(
            fixture_setup.InitctlEnvironmentVariable(
                UBUNTU_PLATFORM_API_TEST_OVERRIDE='sensors'))

        self.addCleanup(process_helpers.stop_job, 'unity8')
        restart_thread = threading.Thread(
            target=self._restart_unity_with_testability)
        restart_thread.start()

        self._create_sensors()

        restart_thread.join()
        self.fake_sensors = sensors.FakePlatformSensors()

    def _restart_unity_with_testability(self):
        self.unity_proxy = process_helpers.restart_unity_with_testability()
        self.main_win = self.unity_proxy.select_single(main_window_emulator.QQuickView)

    def _create_sensors(self):
        # Wait for unity to start running.
        Eventually(Equals(True)).match(
            lambda: process_helpers.is_job_running('unity8'))

        # Wait for the sensors fifo file to be created.
        fifo_path = '/tmp/sensor-fifo-{0}'.format(
            process_helpers.get_unity_pid())
        Eventually(Equals(True)).match(
            lambda: os.path.exists(fifo_path))

        with open(fifo_path, 'w') as fifo:
            fifo.write('create accel 0 1000 0.1\n')
            fifo.write('create light 0 10 1\n')
            fifo.write('create proximity\n') 

class LaunchDashApp(fixtures.Fixture):

    """Fixture to launch the Dash app."""

    def __init__(self, binary_path, variables):
        """Initialize an instance.

        :param str binary_path: The path to the Dash app binary.
        :param variables: The variables to use when launching the app.
        :type variables: A dictionary.

        """
        super(LaunchDashApp, self).__init__()
        self.binary_path = binary_path
        self.variables = variables

    def setUp(self):
        """Launch the dash app when the fixture is used."""
        super(LaunchDashApp, self).setUp()
        self.addCleanup(self.stop_application)
        self.application_proxy = self.launch_application()

    def launch_application(self):
        binary_arg = 'BINARY={}'.format(self.binary_path)
        testability_arg = 'QT_LOAD_TESTABILITY={}'.format(1)
        env_args = [
            '{}={}'.format(key, value) for key, value in self.variables.items()
        ]
        all_args = [binary_arg, testability_arg] + env_args

        pid = process_helpers.start_job('unity8-dash', *all_args)
        return introspection.get_proxy_object_for_existing_process(
            pid=pid,
            emulator_base=emulators.UnityEmulatorBase,
        )

    def stop_application(self):
        process_helpers.stop_job('unity8-dash')


class DisplayRotationLock(fixtures.Fixture):

    def __init__(self, enable):
        super(DisplayRotationLock, self).__init__()
        self.enable = enable

    def setUp(self):
        super(DisplayRotationLock, self).setUp()
        original_state = self._is_rotation_lock_enabled()
        if self.enable != original_state:
            self.addCleanup(self._set_rotation_lock, original_state)
            self._set_rotation_lock(self.enable)

    def _is_rotation_lock_enabled(self):
        command = [
            'gsettings', 'get',
            'com.ubuntu.touch.system',
            'rotation-lock'
        ]
        output = subprocess.check_output(command, universal_newlines=True)
        return True if output.count('true') else False

    def _set_rotation_lock(self, value):
        value_string = 'true' if value else 'false'
        command = [
            'gsettings', 'set',
            'com.ubuntu.touch.system',
            'rotation-lock', value_string
        ]
        subprocess.check_output(command)
