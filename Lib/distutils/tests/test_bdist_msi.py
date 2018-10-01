"""Tests for distutils.command.bdist_msi."""
import platform
import sys
import unittest
from test.support import run_unittest
from distutils.tests import support


SKIP_MESSAGE = (None if sys.platform == "win32" and platform.win32_editionId() != 'IoTUAP' else
                "These tests require Windows x86 or x64.  ARM is not supported")

@unittest.skipUnless(SKIP_MESSAGE is None, SKIP_MESSAGE)
class BDistMSITestCase(support.TempdirManager,
                       support.LoggingSilencer,
                       unittest.TestCase):

    def test_minimal(self):
        # minimal test XXX need more tests
        from distutils.command.bdist_msi import bdist_msi
        project_dir, dist = self.create_dist()
        cmd = bdist_msi(dist)
        cmd.ensure_finalized()


def test_suite():
    return unittest.makeSuite(BDistMSITestCase)

if __name__ == '__main__':
    run_unittest(test_suite())
