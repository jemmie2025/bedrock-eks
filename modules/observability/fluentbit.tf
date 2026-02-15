# FluentBit for Container Logs to CloudWatch

################################################################################
# IAM Role for FluentBit with IRSA
################################################################################

data "aws_iam_policy_document" "fluent_bit_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:fluent-bit"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "fluent_bit" {
  name               = "${var.cluster_name}-fluent-bit-role"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "fluent_bit" {
  statement {
    sid    = "CloudWatchLogPermissions"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "fluent_bit" {
  name        = "${var.cluster_name}-fluent-bit-policy"
  description = "IAM policy for FluentBit to write logs to CloudWatch"
  policy      = data.aws_iam_policy_document.fluent_bit.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fluent_bit" {
  policy_arn = aws_iam_policy.fluent_bit.arn
  role       = aws_iam_role.fluent_bit.name
}

################################################################################
# CloudWatch Log Groups for retail-store-sample-app Logs
################################################################################

resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/eks/${var.cluster_name}/retail-store-sample-app"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-retail-store-sample-app-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "dataplane_logs" {
  name              = "/aws/eks/${var.cluster_name}/dataplane"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-dataplane-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "host_logs" {
  name              = "/aws/eks/${var.cluster_name}/host"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-host-logs"
    }
  )
}

################################################################################
# Kubernetes Resources for FluentBit
################################################################################

resource "kubernetes_namespace" "amazon_cloudwatch" {
  metadata {
    name = "amazon-cloudwatch"

    labels = {
      name = "amazon-cloudwatch"
    }
  }
}

resource "kubernetes_service_account" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit.arn
    }
  }
}

resource "kubernetes_config_map" "fluent_bit_config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }

  data = {
    "fluent-bit.conf" = <<-EOT
      [SERVICE]
          Flush                     5
          Log_Level                 info
          Daemon                    off
          Parsers_File              parsers.conf

      [INPUT]
          Name                tail
          Path                /var/log/containers/*.log
          Parser              docker
          Tag                 kube.*
          Refresh_Interval    5
          Mem_Buf_Limit       50MB
          Skip_Long_Lines     On

      [INPUT]
          Name                systemd
          Tag                 dataplane.systemd.*
          Systemd_Filter      _SYSTEMD_UNIT=docker.service
          Systemd_Filter      _SYSTEMD_UNIT=kubelet.service
          Read_From_Tail      On

      [FILTER]
          Name                kubernetes
          Match               kube.*
          Kube_URL            https://kubernetes.default.svc:443
          Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
          Kube_Tag_Prefix     kube.var.log.containers.
          Merge_Log           On
          Keep_Log            Off
          K8S-Logging.Parser  On
          K8S-Logging.Exclude On
          Buffer_Size         0

      [OUTPUT]
          Name                cloudwatch_logs
          Match               kube.*
          region              ${var.aws_region}
          log_group_name      /aws/eks/${var.cluster_name}/retail-store-sample-app
          log_stream_prefix   from-fluent-bit-
          auto_create_group   false

      [OUTPUT]
          Name                cloudwatch_logs
          Match               dataplane.*
          region              ${var.aws_region}
          log_group_name      /aws/eks/${var.cluster_name}/dataplane
          log_stream_prefix   from-fluent-bit-
          auto_create_group   false
    EOT

    "parsers.conf" = <<-EOT
      [PARSER]
          Name                docker
          Format              json
          Time_Key            time
          Time_Format         %Y-%m-%dT%H:%M:%S.%LZ
          Time_Keep           On

      [PARSER]
          Name                syslog
          Format              regex
          Regex               ^\<(?<pri>[0-9]+)\>(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$
          Time_Key            time
          Time_Format         %b %d %H:%M:%S
    EOT
  }
}

resource "kubernetes_cluster_role" "fluent_bit" {
  metadata {
    name = "fluent-bit"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "pods/logs"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "fluent_bit" {
  metadata {
    name = "fluent-bit"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluent_bit.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluent_bit.metadata[0].name
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }
}

resource "kubernetes_daemonset" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

    labels = {
      k8s-app                         = "fluent-bit"
      version                         = "v1"
      "kubernetes.io/cluster-service" = "true"
    }
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "fluent-bit"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app                         = "fluent-bit"
          version                         = "v1"
          "kubernetes.io/cluster-service" = "true"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.fluent_bit.metadata[0].name

        container {
          name  = "fluent-bit"
          image = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"

          image_pull_policy = "Always"

          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }

          env {
            name  = "CLUSTER_NAME"
            value = var.cluster_name
          }

          env {
            name  = "HOST_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name  = "CI_VERSION"
            value = "k8s/1.3.12"
          }

          resources {
            limits = {
              memory = "200Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }

          volume_mount {
            name       = "fluentbitstate"
            mount_path = "/var/fluent-bit/state"
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
            read_only  = true
          }

          volume_mount {
            name       = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }

          volume_mount {
            name       = "fluent-bit-config"
            mount_path = "/fluent-bit/etc/"
          }

          volume_mount {
            name       = "runlogjournal"
            mount_path = "/run/log/journal"
            read_only  = true
          }

          volume_mount {
            name       = "dmesg"
            mount_path = "/var/log/dmesg"
            read_only  = true
          }
        }

        termination_grace_period_seconds = 10

        volume {
          name = "fluentbitstate"
          host_path {
            path = "/var/fluent-bit/state"
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }

        volume {
          name = "fluent-bit-config"
          config_map {
            name = kubernetes_config_map.fluent_bit_config.metadata[0].name
          }
        }

        volume {
          name = "runlogjournal"
          host_path {
            path = "/run/log/journal"
          }
        }

        volume {
          name = "dmesg"
          host_path {
            path = "/var/log/dmesg"
          }
        }

        toleration {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        toleration {
          operator = "Exists"
          effect   = "NoExecute"
        }

        toleration {
          operator = "Exists"
          effect   = "NoSchedule"
        }
      }
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.application_logs,
    aws_cloudwatch_log_group.dataplane_logs,
    kubernetes_config_map.fluent_bit_config
  ]
}