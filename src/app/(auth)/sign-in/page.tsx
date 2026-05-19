import { PageHeader } from "@/components/common/page-header"
import { SignInForm } from "@/components/forms/sign-in-form"

export default function SignInPage() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="로그인"
        description="계정에 로그인하세요"
      />
      <SignInForm />
    </div>
  )
}
