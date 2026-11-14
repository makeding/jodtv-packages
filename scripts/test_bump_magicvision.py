import importlib.util
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch


spec = importlib.util.spec_from_file_location("bump_magicvision", Path(__file__).with_name("bump-magicvision.py"))
bump = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bump)

REVISION = "4" * 40
URL = "https://github.com/makeding/mAgicVISION/releases/download/v2/magicvision-firmware_0.1.1_all.deb"
DRIVER = ('version = "unstable-2026-11-04-${kernel.version}";\n'
          'rev = "' + "1" * 40 + '";\nhash = "sha256-old";\n')
FIRMWARE = ('version = "0.1.0";\nurl = "https://example.invalid/old.deb";\n'
            'hash = "sha256-old";\n')
RELEASE = {"tag_name": "v2", "assets": [{
    "name": "magicvision-firmware_0.1.1_all.deb", "browser_download_url": URL,
}]}
COMMIT = {"sha": REVISION, "commit": {"committer": {"date": "2026-11-05T15:59:53Z"}}}


class MagicvisionBumpTests(unittest.TestCase):
    def test_release_with_encoded_firmware_version(self):
        driver = MagicMock()
        firmware = MagicMock()
        driver.read_text.return_value = DRIVER
        firmware.read_text.return_value = FIRMWARE
        url = ("https://github.com/makeding/mAgicVISION/releases/download/v3-0.3.1/"
               "magicvision-firmware_0.3.0%2Babi3_all.deb")
        release = {"tag_name": "v3-0.3.1", "assets": [{
            "name": "magicvision-firmware_0.3.0+abi3_all.deb",
            "browser_download_url": url,
        }]}
        with patch.object(bump, "DRIVER", driver), patch.object(bump, "FIRMWARE", firmware), \
             patch.object(bump, "github_json", side_effect=[release, COMMIT]), \
             patch.object(bump, "source_hash", return_value="sha256-source"), \
             patch.object(bump, "file_hash", return_value="sha256-firmware") as file_hash:
            self.assertTrue(bump.update())
        file_hash.assert_called_once_with(url)
        updated = firmware.write_text.call_args.args[0]
        self.assertIn('version = "0.3.0+abi3";', updated)
        self.assertIn(f'url = "{url}";', updated)
        driver.write_text.assert_called_once()

    def test_release_updates_driver_and_firmware_together(self):
        driver = MagicMock()
        firmware = MagicMock()
        driver.read_text.return_value = DRIVER
        firmware.read_text.return_value = FIRMWARE
        with patch.object(bump, "DRIVER", driver), patch.object(bump, "FIRMWARE", firmware), \
             patch.object(bump, "github_json", side_effect=[RELEASE, COMMIT]) as github, \
             patch.object(bump, "source_hash", return_value="sha256-source"), \
             patch.object(bump, "file_hash", return_value="sha256-firmware"):
            self.assertTrue(bump.update())
        self.assertEqual([call.args[0] for call in github.call_args_list],
                         ["releases/latest", "commits/v2"])
        updated_driver = driver.write_text.call_args.args[0]
        updated_firmware = firmware.write_text.call_args.args[0]
        self.assertIn(f'rev = "{REVISION}";', updated_driver)
        self.assertIn('version = "unstable-2026-11-05-${kernel.version}";', updated_driver)
        self.assertIn('hash = "sha256-source";', updated_driver)
        self.assertIn('version = "0.1.1";', updated_firmware)
        self.assertIn(f'url = "{URL}";', updated_firmware)
        self.assertIn('hash = "sha256-firmware";', updated_firmware)

    def test_invalid_firmware_digest_preserves_both_pins(self):
        driver = MagicMock()
        firmware = MagicMock()
        driver.read_text.return_value = DRIVER
        firmware.read_text.return_value = FIRMWARE
        release = {**RELEASE, "assets": [{**RELEASE["assets"][0], "digest": "sha256:" + "0" * 64}]}
        with patch.object(bump, "DRIVER", driver), patch.object(bump, "FIRMWARE", firmware), \
             patch.object(bump, "github_json", side_effect=[release, COMMIT]), \
             patch.object(bump, "source_hash", return_value="sha256-source"), \
             patch.object(bump, "file_hash", return_value="sha256-firmware"), \
             patch.object(bump, "output", return_value="f" * 64):
            with self.assertRaisesRegex(ValueError, "digest"):
                bump.update()
        driver.write_text.assert_not_called()
        firmware.write_text.assert_not_called()


if __name__ == "__main__":
    unittest.main()
