# -*- Mode: Python; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
# Copyright 2013 Canonical
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.

"""unity8 autopilot tests."""

from autopilot.platform import model
from autopilot.testcase import AutopilotTestCase
import logging
import os.path
import sysconfig


from unity8.shell.emulators.main_window import MainWindow


logger = logging.getLogger(__name__)


class FormFactors(object):
    Phone, Tablet, Desktop = range(3)


class Unity8TestCase(AutopilotTestCase):

    """A sane test case base class for the Unity8 shell tests."""

    def launch_unity(self):
        """Launch the unity8 shell, return a proxy object for it."""
        shell_binary_path = self._get_shell_binary_path()
        app_proxy = self.launch_test_application(
               shell_binary_path,
               "-fullscreen",
               app_type='qt'
               )
        logger.debug("Started unity8 shell, backend is: %r", app_proxy._Backend)
        return app_proxy


    def _get_shell_binary_path(self):
        """Return a path to the unity8 binary, either the locally built binary
        or the version installed on the system.

        The locally built binary will be preferred.

        """

        local_path = os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "../../../../../builddir/unity8"
                )
            )
        if os.path.exists(local_path):
            return local_path
        try:
            return subprocess.check_output(['which', 'unity8']).strip()
        except subprocess.CalledProcessError as e:
            self.fail("Unable to locate unity8 binary: %r" % e)


class ShellTestCase(AutopilotTestCase):

    """A common test case class that provides several useful methods for shell tests."""

    libdir = "/usr/lib/{0}/unity8".format(sysconfig.get_config_var('MULTIARCH'))
    lightdm_mock = "full"

    def setUp(self, geometry, grid_size):
        super(ShellTestCase, self).setUp()
        # Lets assume we are installed system wide if this file is somewhere in /usr
        if grid_size != "0":
            os.environ['GRID_UNIT_PX'] = grid_size
            self.grid_size = int(grid_size)
        else:
            self.grid_size = int(os.environ['GRID_UNIT_PX'])
        # launch the local binary if it exists, system binary otherwise
        local_path = os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "../../../../../builddir/unity8"
                )
            )
        if os.path.exists(local_path):
            self.launch_test_local(geometry)
        else:
            self.launch_test_installed(geometry)

    def launch_test_local(self, geometry):
        # TODO: This assumed we're launching the tests from the autopilot test root
        # dir, which may not always be the case.
        os.environ['LD_LIBRARY_PATH'] = "../../builddir/tests/mocks/libusermetrics:../../builddir/tests/mocks/LightDM" + self.lightdm_mock
        os.environ['QML2_IMPORT_PATH'] = "../../builddir/tests/mocks"
        if geometry != "0x0":
            self.app = self.launch_test_application(
                "../../builddir/unity8", "-geometry", geometry, "-frameless", app_type='qt')
        else:
            self.app = self.launch_test_application(
                "../../builddir/unity8", "-fullscreen", app_type='qt')

    def launch_test_installed(self, geometry):
        os.environ['LD_LIBRARY_PATH'] = "{0}/qml/mocks/libusermetrics:{0}/qml/mocks/LightDM/{1}".format(self.libdir, self.lightdm_mock)
        os.environ['QML2_IMPORT_PATH'] = "{0}/qml/mocks".format(self.libdir)
        if model() == 'Desktop' and geometry != "0x0":
            self.app = self.launch_test_application(
               "unity8", "-geometry", geometry, "-frameless", app_type='qt')
        else:
            self.app = self.launch_test_application(
               "unity8", "-fullscreen", app_type='qt')

    def skipWrapper(*args, **kwargs):
        pass

    def form_factor(self):
        return FormFactors.Desktop

    def __getattribute__(self, attr_name):
        attr = object.__getattribute__(self, attr_name);
        if attr_name.startswith("test_"):
            try:
                if self.form_factor() in attr.blacklist:
                    return self.skipWrapper
            except:
                pass
        return attr

    @property
    def main_window(self):
        return MainWindow(self.app)
