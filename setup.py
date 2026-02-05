# pylint: skip-file
import setuptools

setuptools.setup(
   name='rebasebot',
   version='0.0.1',
   description='A tool to sync downstream repositories with their upstream ',
   author='Mikhail Fedosin',
   author_email='mfedosin@redhat.com',
   packages=['rebasebot'],
   install_requires=[
       'cryptography>=3.4.7',
       'gitpython>=3.1.18',
       'github3.py>=3.0.0',
       'PyJWT>=2.0.0,<2.11.0',
       'requests>=2.26.0',
       'validators>=0.18.2'
   ], #external packages as dependencies
   scripts=['rebasebot/cli.py'],
   include_package_data=True,
   package_data={'rebasebot': ['builtin-hooks/**']}
)
