import json
import os
import urllib.error
import urllib.parse
import urllib.request
from base64 import b64encode

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


def _require_env(name: str) -> str:
    value = os.getenv(name, "")
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def _get_vault_token_from_aws_auth() -> str:
    vault_addr = _require_env("VAULT_ADDR").rstrip("/")
    vault_auth_path = _require_env("VAULT_AUTH_PATH").strip("/")
    vault_auth_role = _require_env("VAULT_AUTH_ROLE")
    vault_namespace = os.getenv("VAULT_NAMESPACE", "")

    sts_body = "Action=GetCallerIdentity&Version=2011-06-15"
    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or "us-east-1"
    sts_url = f"https://sts.{region}.amazonaws.com/"
    sts_host = urllib.parse.urlparse(sts_url).netloc

    session = boto3.Session()
    credentials = session.get_credentials()
    if credentials is None:
        raise RuntimeError("No AWS credentials available for Vault AWS IAM authentication")

    frozen_credentials = credentials.get_frozen_credentials()

    signed_request = AWSRequest(
        method="POST",
        url=sts_url,
        data=sts_body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
            "Host": sts_host,
        },
    )
    SigV4Auth(frozen_credentials, "sts", region).add_auth(signed_request)

    iam_request_headers = dict(signed_request.headers.items())

    login_payload = json.dumps(
        {
            "role": vault_auth_role,
            "iam_http_request_method": "POST",
            "iam_request_url": b64encode(sts_url.encode("utf-8")).decode("utf-8"),
            "iam_request_body": b64encode(sts_body.encode("utf-8")).decode("utf-8"),
            "iam_request_headers": b64encode(json.dumps(iam_request_headers).encode("utf-8")).decode("utf-8"),
        }
    ).encode("utf-8")

    login_request = urllib.request.Request(
        f"{vault_addr}/v1/auth/{vault_auth_path}/login",
        data=login_payload,
        method="POST",
        headers={
            "Content-Type": "application/json",
        },
    )

    if vault_namespace:
        login_request.add_header("X-Vault-Namespace", vault_namespace)

    try:
        with urllib.request.urlopen(login_request, timeout=30) as response:
            login_data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"Vault AWS auth login failed: {error.code} {body}") from error

    auth_data = login_data.get("auth", {})
    client_token = auth_data.get("client_token")
    if not client_token:
        raise RuntimeError("Vault AWS auth response did not include a client token")

    return client_token


def _request_vault_certificate(vault_token: str) -> tuple[str, str, str]:
    vault_addr = _require_env("VAULT_ADDR").rstrip("/")
    vault_pki_path = _require_env("VAULT_PKI_PATH").strip("/")
    vault_pki_role = _require_env("VAULT_PKI_ROLE")
    cert_common_name = _require_env("CERT_COMMON_NAME")
    cert_ttl = _require_env("CERT_TTL")
    vault_namespace = os.getenv("VAULT_NAMESPACE", "")

    issue_url = f"{vault_addr}/v1/{vault_pki_path}/issue/{vault_pki_role}"
    payload = json.dumps(
        {
            "common_name": cert_common_name,
            "ttl": cert_ttl,
        }
    ).encode("utf-8")

    request = urllib.request.Request(
        issue_url,
        data=payload,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "X-Vault-Token": vault_token,
        },
    )

    if vault_namespace:
        request.add_header("X-Vault-Namespace", vault_namespace)

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            response_data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"Vault request failed: {error.code} {body}") from error

    data = response_data.get("data", {})
    certificate_body = data.get("certificate")
    private_key = data.get("private_key")
    issuing_ca = data.get("issuing_ca", "")
    ca_chain_items = data.get("ca_chain", [])

    if not certificate_body or not private_key:
        raise RuntimeError("Vault response did not include certificate and private key")

    certificate_chain = issuing_ca
    if ca_chain_items:
        certificate_chain = "\n".join(ca_chain_items)

    return certificate_body, private_key, certificate_chain


def lambda_handler(event, context):
    certificate_arn = _require_env("ACM_CERTIFICATE_ARN")
    acm_client = boto3.client("acm")
    vault_token = _get_vault_token_from_aws_auth()

    certificate_body, private_key, certificate_chain = _request_vault_certificate(vault_token)

    request = {
        "CertificateArn": certificate_arn,
        "Certificate": certificate_body.encode("utf-8"),
        "PrivateKey": private_key.encode("utf-8"),
    }

    if certificate_chain:
        request["CertificateChain"] = certificate_chain.encode("utf-8")

    result = acm_client.import_certificate(**request)

    return {
        "status": "success",
        "certificate_arn": result.get("CertificateArn", certificate_arn),
        "message": "Certificate renewed from Vault PKI and imported to ACM",
    }
